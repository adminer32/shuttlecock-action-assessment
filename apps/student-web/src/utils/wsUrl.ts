/**
 * WebSocket 地址解析
 *
 * 开发环境：由 `.env.dev` 的 `VITE_WS_BASE_URL` 指定（如 ws://localhost:8001），
 *          或走 Vite 代理。
 * 生产/容器环境：构建时通常不注入该变量，此时自动回退为「同源」地址，
 *          即当前页面的 ws:// 或 wss:// 主机名，由 Nginx 反向代理到后端。
 *          这样前后端同域部署无需任何额外配置。
 */
export function resolveWsBaseUrl(): string {
    const configured = import.meta.env.VITE_WS_BASE_URL;
    if (configured) {
        return String(configured).replace(/\/+$/, '');
    }
    if (typeof window !== 'undefined' && window.location) {
        const scheme = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        return `${scheme}//${window.location.host}`;
    }
    return '';
}

/**
 * 拼接完整 WebSocket 地址。
 * @param path 以 / 开头的路径，如 `/ws/ai`
 * @param query 可选的查询参数（token 等）
 */
export function buildWsUrl(path: string, query?: Record<string, string | null>): string {
    const base = resolveWsBaseUrl();
    const params = new URLSearchParams();
    if (query) {
        Object.entries(query).forEach(([key, value]) => {
            if (value !== null && value !== undefined) {
                params.set(key, value);
            }
        });
    }
    const qs = params.toString();
    return `${base}${path}${qs ? `?${qs}` : ''}`;
}
