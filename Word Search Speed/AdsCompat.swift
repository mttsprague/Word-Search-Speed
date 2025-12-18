// Put this in a small AdsCompat.swift, compiled only when GoogleMobileAds is available.
#if canImport(GoogleMobileAds)
import GoogleMobileAds
internal let AdsSimulatorID: String = {
    // Prefer the SDK's constant if it exists; otherwise fallback to literal.
    return "SIMULATOR"
}()
#endif
