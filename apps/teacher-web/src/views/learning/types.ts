export type PlanReviewStatus = 'pending' | 'approved' | 'rejected'

export interface Student {
  id: number
  name: string
  studentId: string
  planStatus: 'completed' | 'progress' | 'pending'
  weakness: string
  progress: number
}

export interface TrainingTask {
  name?: string
  spec?: string
  video?: string
  day?: string
  content?: string
  duration?: number
  target?: string
  action?: string
}

/**
 * 训练计划视图模型。
 *
 * 与后端 `learningApi.PlanDetail` 保持一致：`id` 为计划主键
 * （审批 / 保存时需要回传），并补充周次与周起始日期等展示字段。
 */
export interface TrainingPlan {
  id?: number
  goal: string
  tasks: TrainingTask[]
  progress: number
  reviewStatus?: PlanReviewStatus
  reviewComment?: string
  generatedAt?: string
  weekNumber?: number
  totalWeeks?: number
  weekStart?: string
  weekEnd?: string
}

export interface VideoItem {
  /** 视频主键；后端返回数字，前端表单可能是字符串，故两者都允许 */
  id: number | string
  title: string
  duration: string
  url: string
  category: string
  description?: string
  recommendedTo?: number[]
}

export interface VideoRecommendation {
  videoId: number
  studentId: number
  comment?: string
  recommendedAt: string
}

export interface VideoFormData {
  title: string
  duration: string
  url: string
  category: string
}
