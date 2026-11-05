import std/[unittest, options], necsuspd/assetBag

type TestImages = enum
  FirstImage
  MapBackground1
  TilesFactoryFloor

suite "Asset bag keys":
  test "findAssetBagKey converts paths to keys":
    check(
      "../source/images/map-background-1.png".findAssetBagKey(TestImages) ==
        MapBackground1
    )
    check(
      "../source/images/tiles-factory-floor-table-16-16.png".findAssetBagKey(TestImages) ==
        TilesFactoryFloor
    )

  test "findAssetBagKey falls back to the first value":
    check("../source/images/missing.png".findAssetBagKey(TestImages) == FirstImage)

  test "tryFindAssetBagKey reports unmatched paths":
    check(
      "../source/images/map-background-1.png".tryFindAssetBagKey(TestImages) ==
        some(MapBackground1)
    )
    check(
      "../source/images/missing.png".tryFindAssetBagKey(TestImages) == none(TestImages)
    )
