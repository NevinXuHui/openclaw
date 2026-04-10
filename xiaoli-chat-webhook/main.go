package main

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

// WebhookPayload 定义 webhook 接收的数据结构
type WebhookPayload struct {
	Event     string                 `json:"event"`
	Timestamp int64                  `json:"timestamp"`
	Data      map[string]interface{} `json:"data"`
}

// OpenClawMessage 发送给 OpenClaw 的消息结构
type OpenClawMessage struct {
	Channel string `json:"channel"`
	User    string `json:"user"`
	Message string `json:"message"`
}

// ReplyMessage 存储回复消息
type ReplyMessage struct {
	ChatID    string    `json:"chatId"`
	Text      string    `json:"text"`
	ThreadID  string    `json:"threadId,omitempty"`
	Timestamp time.Time `json:"timestamp"`
}

// SSEClient SSE 客户端连接
type SSEClient struct {
	ChatID  string
	Channel chan ReplyMessage
}

var (
	webhookSecret  = os.Getenv("WEBHOOK_SECRET")
	openclawURL    = os.Getenv("OPENCLAW_URL") // OpenClaw gateway 地址
	openclawToken  = os.Getenv("OPENCLAW_TOKEN")
	xiaoliToken    = getEnv("XIAOLI_TOKEN", "test-token-12345") // Xiaoli Chat API token
	listenPort     = getEnv("PORT", "8080")
	recentReplies  = make([]ReplyMessage, 0, 100) // 存储最近 100 条回复
	sseClients     = make(map[*SSEClient]bool)    // SSE 客户端连接池
)

func main() {
	if webhookSecret == "" {
		log.Fatal("WEBHOOK_SECRET 环境变量未设置")
	}
	if openclawURL == "" {
		openclawURL = "http://localhost:18789" // 默认 OpenClaw gateway 地址
	}

	http.HandleFunc("/webhook", handleWebhook)
	http.HandleFunc("/messages", handleMessages)
	http.HandleFunc("/replies", handleGetReplies)
	http.HandleFunc("/stream", handleSSEStream)
	http.HandleFunc("/health", handleHealth)

	log.Printf("Xiaoli Chat Webhook 服务器启动在端口 %s", listenPort)
	log.Printf("OpenClaw URL: %s", openclawURL)
	if err := http.ListenAndServe(":"+listenPort, nil); err != nil {
		log.Fatal(err)
	}
}

// handleWebhook 处理来自 Xiaoli Chat 的 webhook 请求
func handleWebhook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "只支持 POST 请求", http.StatusMethodNotAllowed)
		return
	}

	// 读取请求体
	body, err := io.ReadAll(r.Body)
	if err != nil {
		log.Printf("读取请求体失败: %v", err)
		http.Error(w, "读取请求失败", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	// 验证签名
	signature := r.Header.Get("x-xiaoli-signature")
	if !verifySignature(body, signature) {
		log.Printf("签名验证失败")
		http.Error(w, "签名验证失败", http.StatusUnauthorized)
		return
	}

	// 解析 payload
	var payload WebhookPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		log.Printf("解析 JSON 失败: %v", err)
		http.Error(w, "无效的 JSON", http.StatusBadRequest)
		return
	}

	log.Printf("收到 webhook: event=%s, timestamp=%d", payload.Event, payload.Timestamp)

	// 处理不同类型的事件
	switch payload.Event {
	case "message":
		handleMessageEvent(payload.Data)
	case "user_joined":
		log.Printf("用户加入: %v", payload.Data)
	default:
		log.Printf("未知事件类型: %s", payload.Event)
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

// handleMessageEvent 处理消息事件
func handleMessageEvent(data map[string]interface{}) {
	user, _ := data["user"].(string)
	message, _ := data["message"].(string)
	channel, _ := data["channel"].(string)

	log.Printf("收到消息: user=%s, channel=%s, message=%s", user, channel, message)

	// 转发消息到 OpenClaw
	if err := forwardToOpenClaw(channel, user, message); err != nil {
		log.Printf("转发到 OpenClaw 失败: %v", err)
	}
}

// forwardToOpenClaw 将消息转发到 OpenClaw xiaoli-chat webhook 端点
func forwardToOpenClaw(channel, user, message string) error {
	// 构造 OpenClaw xiaoli-chat 插件期望的消息格式
	xiaoliMsg := map[string]interface{}{
		"senderId":        user,
		"chatId":          channel,
		"messageId":       fmt.Sprintf("msg-%d", time.Now().UnixNano()),
		"text":            message,
		"isDirectMessage": true,
	}

	jsonData, err := json.Marshal(xiaoliMsg)
	if err != nil {
		return fmt.Errorf("序列化消息失败: %w", err)
	}

	// 生成 OpenClaw 期望的签名
	signature := generateOpenClawSignature(jsonData)

	// 转发到 OpenClaw 的 xiaoli-chat webhook 端点
	req, err := http.NewRequest("POST", openclawURL+"/hooks/xiaoli-chat/webhook", bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("创建请求失败: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-xiaoli-signature", "sha256="+signature)

	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("发送请求失败: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusAccepted {
		return fmt.Errorf("OpenClaw 返回错误: status=%d, body=%s", resp.StatusCode, string(body))
	}

	log.Printf("消息已转发到 OpenClaw: status=%d, response=%s", resp.StatusCode, string(body))
	return nil
}

// generateOpenClawSignature 生成 OpenClaw 期望的 HMAC-SHA256 签名
func generateOpenClawSignature(body []byte) string {
	mac := hmac.New(sha256.New, []byte(webhookSecret))
	mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

// verifySignature 验证 webhook 签名
func verifySignature(body []byte, signature string) bool {
	if webhookSecret == "" || signature == "" {
		return false
	}

	mac := hmac.New(sha256.New, []byte(webhookSecret))
	mac.Write(body)
	expectedSignature := hex.EncodeToString(mac.Sum(nil))

	return hmac.Equal([]byte(signature), []byte(expectedSignature))
}

// handleSSEStream 处理 SSE 流连接
func handleSSEStream(w http.ResponseWriter, r *http.Request) {
	// 设置 SSE 响应头
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	// 获取 chatId 过滤参数
	chatID := r.URL.Query().Get("chatId")

	// 创建客户端
	client := &SSEClient{
		ChatID:  chatID,
		Channel: make(chan ReplyMessage, 10),
	}

	// 注册客户端
	sseClients[client] = true
	log.Printf("SSE 客户端连接: chatId=%s, 当前连接数=%d", chatID, len(sseClients))

	// 发送连接成功消息
	fmt.Fprintf(w, "data: {\"type\":\"connected\",\"chatId\":\"%s\"}\n\n", chatID)
	w.(http.Flusher).Flush()

	// 监听客户端断开
	notify := r.Context().Done()

	// 事件循环
	for {
		select {
		case <-notify:
			// 客户端断开
			delete(sseClients, client)
			close(client.Channel)
			log.Printf("SSE 客户端断开: chatId=%s, 剩余连接数=%d", chatID, len(sseClients))
			return

		case reply := <-client.Channel:
			// 发送回复消息
			data, _ := json.Marshal(reply)
			fmt.Fprintf(w, "data: %s\n\n", string(data))
			w.(http.Flusher).Flush()
		}
	}
}

// broadcastToSSEClients 广播回复到所有 SSE 客户端
func broadcastToSSEClients(reply ReplyMessage) {
	for client := range sseClients {
		// 如果客户端指定了 chatId，只发送匹配的消息
		if client.ChatID == "" || client.ChatID == reply.ChatID {
			select {
			case client.Channel <- reply:
				// 发送成功
			default:
				// 通道已满，跳过
				log.Printf("SSE 客户端通道已满，跳过消息: chatId=%s", client.ChatID)
			}
		}
	}
	log.Printf("广播回复到 %d 个 SSE 客户端", len(sseClients))
}

// handleGetReplies 查询最近的回复
func handleGetReplies(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "只支持 GET 请求", http.StatusMethodNotAllowed)
		return
	}

	// 可选的查询参数
	chatID := r.URL.Query().Get("chatId")
	limitStr := r.URL.Query().Get("limit")
	limit := 10 // 默认返回最近 10 条

	if limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}

	// 过滤和返回回复
	var filtered []ReplyMessage
	for i := len(recentReplies) - 1; i >= 0 && len(filtered) < limit; i-- {
		reply := recentReplies[i]
		if chatID == "" || reply.ChatID == chatID {
			filtered = append(filtered, reply)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"replies": filtered,
		"count":   len(filtered),
	})
}

// handleHealth 健康检查端点
func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
		"time":   time.Now().Format(time.RFC3339),
	})
}

// handleMessages 处理来自 OpenClaw 的回复消息
func handleMessages(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "只支持 POST 请求", http.StatusMethodNotAllowed)
		return
	}

	// 验证 Authorization header
	authHeader := r.Header.Get("Authorization")
	expectedAuth := "Bearer " + xiaoliToken
	if authHeader != expectedAuth {
		log.Printf("认证失败: 期望 %s, 收到 %s", expectedAuth, authHeader)
		http.Error(w, "认证失败", http.StatusUnauthorized)
		return
	}

	// 读取请求体
	body, err := io.ReadAll(r.Body)
	if err != nil {
		log.Printf("读取请求体失败: %v", err)
		http.Error(w, "读取请求失败", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	// 解析 OpenClaw 的回复
	var reply struct {
		ChatID   string `json:"chatId"`
		Text     string `json:"text"`
		ThreadID string `json:"threadId,omitempty"`
	}

	if err := json.Unmarshal(body, &reply); err != nil {
		log.Printf("解析 JSON 失败: %v", err)
		http.Error(w, "无效的 JSON", http.StatusBadRequest)
		return
	}

	log.Printf("收到 OpenClaw 回复: chatId=%s, text=%s", reply.ChatID, reply.Text)

	// 创建回复消息
	replyMsg := ReplyMessage{
		ChatID:    reply.ChatID,
		Text:      reply.Text,
		ThreadID:  reply.ThreadID,
		Timestamp: time.Now(),
	}

	// 存储回复到内存
	recentReplies = append(recentReplies, replyMsg)
	// 保持最近 100 条
	if len(recentReplies) > 100 {
		recentReplies = recentReplies[1:]
	}

	// 广播到所有 SSE 客户端
	broadcastToSSEClients(replyMsg)

	// 在真实环境中，这里应该将回复发送到 Xiaoli Chat 平台
	// 现在我们只是记录日志并返回成功
	messageID := fmt.Sprintf("reply-%d", time.Now().UnixNano())

	log.Printf("✅ 回复已处理: messageId=%s", messageID)

	// 返回成功响应（OpenClaw 期望的格式）
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"id": messageID,
	})
}

// getEnv 获取环境变量，如果不存在则返回默认值
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
