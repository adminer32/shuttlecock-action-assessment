/**
 * 与教师端后端（server-java）统一响应包络对应的类型定义。
 * 见 common-core 的 RestResponse：{ code, message, data }
 */
export type Result<T = unknown> = {
    code: number;
    message: string;
    data: T;
};

export enum ThemeEnum {
    AUTO = 'auto', // 跟随系统
    LIGHT = 'light',
    DARK = 'dark',
}

declare module '*.json' {
    const value: Record<string, unknown>;
    export default value;
}
