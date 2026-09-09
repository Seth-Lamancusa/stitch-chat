"""Unit tests for Completions context projection (no network)."""

from openai_compatible import project_context


def test_project_context_maps_roles_including_trailing_trigger():
    messages = project_context(
        [
            {"id": "1", "role": "user", "author_id": "alice", "content": "hi"},
            {"id": "2", "role": "localBot", "author_id": "chatgpt", "content": "hello"},
            {"id": "3", "role": "user", "author_id": "bob", "content": "follow up"},
            {
                "id": "4",
                "role": "user",
                "author_id": "alice",
                "content": "@chatgpt what next?",
            },
        ],
    )
    assert messages == [
        {"role": "user", "content": "hi"},
        {"role": "assistant", "content": "hello"},
        {"role": "user", "content": "follow up"},
        {"role": "user", "content": "@chatgpt what next?"},
    ]


def test_project_context_skips_empty_and_allows_trigger_only():
    assert project_context(
        [{"id": "t", "role": "user", "content": "just the trigger"}]
    ) == [{"role": "user", "content": "just the trigger"}]
    assert project_context(
        [
            {"role": "user", "content": ""},
            {"role": "user", "content": "x"},
        ]
    ) == [{"role": "user", "content": "x"}]
