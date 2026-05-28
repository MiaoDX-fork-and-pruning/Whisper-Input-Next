import asyncio

from src.transcription.doubao_streaming import DoubaoStreamingProcessor, StreamingResult


class FinalizingDoubaoProcessor(DoubaoStreamingProcessor):
    def __init__(self):
        self.receive_timeout_seconds = 0.01
        self.enable_nonstream = True
        self.sent_chunks = []
        self._receive_count = 0
        self._is_connected = False
        self._ws = None
        self._session = None

    def is_available(self) -> bool:
        return True

    async def connect(self) -> bool:
        self._is_connected = True
        return True

    async def disconnect(self):
        self._is_connected = False

    async def send_initial_request(self):
        return StreamingResult()

    async def send_audio_chunk(self, chunk: bytes, is_last: bool = False) -> bool:
        self.sent_chunks.append((chunk, is_last))
        return True

    async def receive_result(self, timeout=None):
        await asyncio.sleep(timeout or self.receive_timeout_seconds)
        self._receive_count += 1
        if self._receive_count == 1:
            return StreamingResult(definite_text="预览")
        if self._receive_count == 2:
            return None
        return StreamingResult(definite_text="最终文本", is_final=True)


def run_processor(processor):
    preview_texts = []
    final_texts = []
    completed = []
    errors = []

    async def audio_chunks():
        yield b"audio"

    asyncio.run(
        processor.process_audio_stream(
            audio_chunks(),
            preview_texts.append,
            final_texts.append,
            lambda: completed.append(True),
            errors.append,
        )
    )
    return preview_texts, final_texts, completed, errors


def test_process_audio_stream_waits_for_service_final_packet():
    processor = FinalizingDoubaoProcessor()
    preview_texts, final_texts, completed, errors = run_processor(processor)

    assert errors == []
    assert preview_texts == ["预览", "最终文本"]
    assert final_texts == ["最终文本"]
    assert completed == [True]
    assert processor.sent_chunks[-1] == (b"", True)
