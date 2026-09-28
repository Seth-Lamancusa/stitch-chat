"""Protocol helpers for ephemeral typing cues."""

import protocol


def test_cue_envelope_on_and_clear():
    on = protocol.cue_envelope(
        author_id="cursor",
        target_message_id="msg-1",
        typing=True,
    )
    assert on == {
        "type": protocol.CUE,
        "author_id": "cursor",
        "target_message_id": "msg-1",
        "typing": True,
    }
    off = protocol.cue_envelope(
        author_id="cursor",
        target_message_id="msg-1",
        typing=False,
    )
    assert off["typing"] is False
    assert off["type"] == "cue"
