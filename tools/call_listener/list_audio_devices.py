try:
    import pyaudiowpatch as pyaudio

    AUDIO_BACKEND = "pyaudiowpatch"
except ImportError:
    import pyaudio

    AUDIO_BACKEND = "pyaudio"


def main() -> None:
    audio = pyaudio.PyAudio()
    try:
        print(f"=== BACKEND: {AUDIO_BACKEND} ===")
        print("=== HOST APIs ===")
        for index in range(audio.get_host_api_count()):
            info = audio.get_host_api_info_by_index(index)
            print(f"[{index}] {info.get('name')} type={info.get('type')}")

        print("\n=== INPUT DEVICES ===")
        for index in range(audio.get_device_count()):
            info = audio.get_device_info_by_index(index)
            if int(info.get("maxInputChannels", 0)) <= 0:
                continue
            host = audio.get_host_api_info_by_index(info.get("hostApi"))
            print(
                f"[{index}] host={host.get('name')} "
                f"ch={int(info.get('maxInputChannels', 0))} "
                f"rate={int(info.get('defaultSampleRate', 0))} "
                f"loopback={bool(info.get('isLoopbackDevice'))} "
                f"name={info.get('name')}"
            )

        print("\n=== LOOPBACK DEVICES ===")
        for index in range(audio.get_device_count()):
            info = audio.get_device_info_by_index(index)
            if not info.get("isLoopbackDevice"):
                continue
            host = audio.get_host_api_info_by_index(info.get("hostApi"))
            print(
                f"[{index}] host={host.get('name')} "
                f"ch={int(info.get('maxInputChannels', 0))} "
                f"rate={int(info.get('defaultSampleRate', 0))} "
                f"name={info.get('name')}"
            )
    finally:
        audio.terminate()


if __name__ == "__main__":
    main()
