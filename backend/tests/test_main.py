import unittest

from google.genai import types

from backend.main import AUDIO_MIME_TYPE, AUDIO_SAMPLE_RATE, build_audio_packet, build_live_connect_config


class BuildLiveConnectConfigTests(unittest.TestCase):
    def test_build_live_connect_config_uses_audio_modality(self):
        config = build_live_connect_config("hello prompt")

        self.assertIsInstance(config, types.LiveConnectConfig)
        self.assertEqual(config.response_modalities, [types.Modality.AUDIO])
        self.assertIsNotNone(config.system_instruction)

    def test_build_audio_packet_uses_consistent_pcm_metadata(self):
        packet = build_audio_packet(b"\x01\x02\x03\x04")

        self.assertEqual(AUDIO_MIME_TYPE, "audio/pcm")
        self.assertEqual(packet["type"], "audio")
        self.assertEqual(packet["mime_type"], AUDIO_MIME_TYPE)
        self.assertEqual(packet["sample_rate"], AUDIO_SAMPLE_RATE)
        self.assertEqual(packet["audio"], "AQIDBA==")


if __name__ == "__main__":
    unittest.main()
