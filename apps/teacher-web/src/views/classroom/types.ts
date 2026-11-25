/**
 * 课堂管理页面类型。
 *
 * 约定：与后端交互的实体（课程、知识点、笔记）以 `@/api/classroomApi` 中的定义为准，
 * 这里只做再导出，并补充纯前端的视图类型，避免两套结构漂移。
 */
export type { ClassroomKnowledgePoint as KnowledgePoint } from '@/api/classroomApi'
export type { ClassroomLesson as LessonItem } from '@/api/classroomApi'
export type { ClassroomNote as NoteItem } from '@/api/classroomApi'

export interface KnowledgePointForm {
  title: string
  description: string
}

export interface Marker {
  time: number
  timeStr: string
  desc: string
  marked: boolean
}

export interface AnalysisResult {
  id: string
  timestamp: number
  type: 'pose' | 'action' | 'technique'
  title: string
  description: string
  score?: number
  suggestions?: string[]
  imageUrl?: string
}

export interface VideoAnalysis {
  videoId: string
  totalScore: number
  poseAnalysis: AnalysisResult[]
  actionAnalysis: AnalysisResult[]
  techniqueAnalysis: AnalysisResult[]
  summary: string
}

export interface LessonVideo {
  id: string
  title: string
  description: string
  videoUrl: string
  thumbnail: string
  duration: string
  recordedAt: string
  classId: number
  className: string
}
