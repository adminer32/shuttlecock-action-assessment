package config

import (
	"encoding/json"
	"os"
	"strconv"
)

// Config 是服务端的全部配置项。
// 配置优先级：环境变量 > configs/config.json > 内置默认值。
type Config struct {
	ServerAddr          string
	VideoBasePath       string
	UploadsPath         string
	Database            DatabaseConfig
	Redis               RedisConfig
	JWT                 JWTConfig
	DeepSeek            DeepSeekConfig
	DashScope           DashScopeConfig
	SendGrid            SendGridConfig
	CloudflareTurnstile CloudflareConfig
}

type DatabaseConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	Charset  string
}

type RedisConfig struct {
	Host     string
	Port     string
	Password string
	DB       int
}

type JWTConfig struct {
	Secret        string
	AccessExpiry  int64 // seconds
	RefreshExpiry int64
}

type DeepSeekConfig struct {
	APIKey  string
	BaseURL string
	Model   string
}

type DashScopeConfig struct {
	APIKey string
}

type SendGridConfig struct {
	APIKey string
}

type CloudflareConfig struct {
	SiteKey   string
	SecretKey string
}

// Load 读取配置文件，并在其后用环境变量覆盖，便于容器化部署。
func Load(path ...string) *Config {
	cfgPath := "configs/config.json"
	if len(path) > 0 && path[0] != "" {
		cfgPath = path[0]
	}

	var cfg Config
	if data, err := os.ReadFile(cfgPath); err == nil {
		if err := json.Unmarshal(data, &cfg); err != nil {
			cfg = *defaultConfig()
		}
	} else {
		cfg = *defaultConfig()
	}

	applyEnv(&cfg)
	return &cfg
}

// applyEnv 用环境变量覆盖配置中的对应字段。
// 只有非空环境变量才会覆盖，未设置时保留配置文件中的值。
func applyEnv(cfg *Config) {
	setStr := func(dst *string, key string) {
		if v := os.Getenv(key); v != "" {
			*dst = v
		}
	}
	setInt := func(dst *int, key string) {
		if v := os.Getenv(key); v != "" {
			if n, err := strconv.Atoi(v); err == nil {
				*dst = n
			}
		}
	}
	setInt64 := func(dst *int64, key string) {
		if v := os.Getenv(key); v != "" {
			if n, err := strconv.ParseInt(v, 10, 64); err == nil {
				*dst = n
			}
		}
	}

	setStr(&cfg.ServerAddr, "SERVER_ADDR")
	setStr(&cfg.VideoBasePath, "VIDEO_BASE_PATH")
	setStr(&cfg.UploadsPath, "UPLOADS_PATH")

	setStr(&cfg.Database.Host, "DB_HOST")
	setStr(&cfg.Database.Port, "DB_PORT")
	setStr(&cfg.Database.User, "DB_USER")
	setStr(&cfg.Database.Password, "DB_PASSWORD")
	setStr(&cfg.Database.DBName, "DB_NAME")
	setStr(&cfg.Database.Charset, "DB_CHARSET")

	setStr(&cfg.Redis.Host, "REDIS_HOST")
	setStr(&cfg.Redis.Port, "REDIS_PORT")
	setStr(&cfg.Redis.Password, "REDIS_PASSWORD")
	setInt(&cfg.Redis.DB, "REDIS_DB")

	setStr(&cfg.JWT.Secret, "JWT_SECRET")
	setInt64(&cfg.JWT.AccessExpiry, "JWT_ACCESS_EXPIRY")
	setInt64(&cfg.JWT.RefreshExpiry, "JWT_REFRESH_EXPIRY")

	setStr(&cfg.DeepSeek.APIKey, "DEEPSEEK_API_KEY")
	setStr(&cfg.DeepSeek.BaseURL, "DEEPSEEK_BASE_URL")
	setStr(&cfg.DeepSeek.Model, "DEEPSEEK_MODEL")

	setStr(&cfg.DashScope.APIKey, "DASHSCOPE_API_KEY")
	setStr(&cfg.SendGrid.APIKey, "SENDGRID_API_KEY")
	setStr(&cfg.CloudflareTurnstile.SiteKey, "CLOUDFLARE_SITE_KEY")
	setStr(&cfg.CloudflareTurnstile.SecretKey, "CLOUDFLARE_SECRET_KEY")
}

func defaultConfig() *Config {
	return &Config{
		ServerAddr:    ":8001",
		VideoBasePath: "./data/videos",
		UploadsPath:   "./data/uploads",
		Database: DatabaseConfig{
			Host:     "127.0.0.1",
			Port:     "3306",
			User:     "root",
			Password: "",
			DBName:   "lingxi_jianqiu",
			Charset:  "utf8mb4",
		},
		Redis: RedisConfig{
			Host: "127.0.0.1",
			Port: "6379",
			DB:   0,
		},
		JWT: JWTConfig{
			Secret:        "change-me-in-production",
			AccessExpiry:  14400,
			RefreshExpiry: 604800,
		},
		DeepSeek: DeepSeekConfig{
			BaseURL: "https://api.deepseek.com/v1",
			Model:   "deepseek-chat",
		},
		DashScope: DashScopeConfig{
			APIKey: "",
		},
	}
}
