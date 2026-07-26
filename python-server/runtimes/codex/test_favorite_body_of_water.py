"""Example test data about a favorite body of water."""


class FavoriteBodyOfWater:
    def __init__(self, name: str, kind: str, highlights: list[str]) -> None:
        self.name = name
        self.kind = kind
        self.highlights = highlights

    def summary(self) -> str:
        return f"{self.name} is a {self.kind} known for {', '.join(self.highlights)}."


def test_favorite_body_of_water_summary() -> None:
    lake_tahoe = FavoriteBodyOfWater(
        name="Lake Tahoe",
        kind="freshwater alpine lake",
        highlights=["clear water", "mountain scenery", "recreation"],
    )

    summary = lake_tahoe.summary()

    assert "Lake Tahoe" in summary
    assert "freshwater alpine lake" in summary
    assert "clear water" in summary


def test_favorite_body_of_water_metadata() -> None:
    lake_tahoe = FavoriteBodyOfWater(
        name="Lake Tahoe",
        kind="freshwater alpine lake",
        highlights=["clear water", "mountain scenery", "recreation"],
    )

    assert lake_tahoe.name == "Lake Tahoe"
    assert lake_tahoe.kind == "freshwater alpine lake"
    assert lake_tahoe.highlights[1] == "mountain scenery"
