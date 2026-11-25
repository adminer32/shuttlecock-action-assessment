"""毽球课堂视频检测服务（可选组件）。

通过 WebSocket 将 YOLOv8 对课堂视频的逐帧检测结果（标注帧 + 出勤率/参与度指标）
实时推送给教师端「课堂管理」页面。

运行前准备：
    pip install -r requirements.txt   # fastapi uvicorn opencv-python ultralytics

指定视频源（不随仓库提交，需自行准备）：
    export YOLO_VIDEO=/path/to/classroom.mp4

启动：
    python yolo_server.py            # 默认监听 0.0.0.0:8000
"""

import base64
import os

import cv2
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from ultralytics import YOLO

app = FastAPI(title="Shuttlecock Classroom Detector")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
VIDEO_PATH = os.environ.get("YOLO_VIDEO", os.path.join(BASE_DIR, "assets", "sample.mp4"))
MODEL_PATH = os.environ.get("YOLO_MODEL", os.path.join(BASE_DIR, "yolov8n.pt"))
FRAME_SKIP = int(os.environ.get("YOLO_FRAME_SKIP", "3"))
EXPECTED_STUDENTS = int(os.environ.get("YOLO_EXPECTED_STUDENTS", "10"))
JPEG_QUALITY = int(os.environ.get("YOLO_JPEG_QUALITY", "60"))

model = YOLO(MODEL_PATH)


def _metrics(detected: int) -> dict:
    """根据当前帧检出的学生人数估算出勤率与参与度。"""
    if EXPECTED_STUDENTS <= 0:
        return {"attendanceRate": 0.0, "engagement": 0.0}
    attendance = min(detected / EXPECTED_STUDENTS, 1.0)
    return {
        "attendanceRate": round(attendance * 100, 1),
        "engagement": round(attendance * 90 + 5, 1),
    }


@app.get("/health")
async def health() -> dict:
    """健康检查，同时报告视频源是否可用。"""
    return {
        "status": "ok",
        "video": VIDEO_PATH,
        "video_exists": os.path.exists(VIDEO_PATH),
        "model": MODEL_PATH,
    }


@app.websocket("/ws/analysis")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await websocket.accept()

    if not os.path.exists(VIDEO_PATH):
        await websocket.send_json(
            {"status": "error", "message": f"视频文件不存在: {VIDEO_PATH}"}
        )
        await websocket.close()
        return

    cap = cv2.VideoCapture(VIDEO_PATH)
    frame_count = 0

    try:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                # 视频播放结束后回到开头循环推送
                cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                ret, frame = cap.read()
                if not ret:
                    break

            frame_count += 1
            if frame_count % FRAME_SKIP != 0:
                continue

            results = model.predict(frame, classes=[0], verbose=False)
            annotated = results[0].plot()
            detected = int(len(results[0].boxes)) if results[0].boxes is not None else 0

            ok, buffer = cv2.imencode(
                ".jpg", annotated, [cv2.IMWRITE_JPEG_QUALITY, JPEG_QUALITY]
            )
            if not ok:
                continue

            payload = {
                "status": "running",
                "frame": frame_count,
                "detected": detected,
                "image": base64.b64encode(buffer.tobytes()).decode("utf-8"),
            }
            payload.update(_metrics(detected))
            await websocket.send_json(payload)
    except WebSocketDisconnect:
        pass
    except Exception as exc:  # noqa: BLE001 - 服务端需记录异常但不中断进程
        print(f"[yolo] 检测流异常: {exc}")
    finally:
        cap.release()


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("YOLO_PORT", "8000")))
