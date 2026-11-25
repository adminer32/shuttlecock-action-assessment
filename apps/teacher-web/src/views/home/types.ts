/**
 * 首页视图层类型。
 *
 * 说明：`ClassOverview` / `PendingItem` / `Notice` 的字段以服务端返回为准，
 * 统一在 `@/api/homeApi` 中定义，这里直接再导出，避免出现两套结构不一致的类型。
 */
export type {
  HomeOverview as ClassOverview,
  PendingItem,
  Notice,
} from '@/api/homeApi'

export interface ScheduleItem {
  id: string
  day: number
  period: number
  courseName: string
  location: string
  duration?: number // 连续节数，默认 1
}
