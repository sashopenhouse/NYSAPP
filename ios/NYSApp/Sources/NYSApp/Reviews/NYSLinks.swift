import Foundation

enum NYSLinks {
    /// Google Place ID for the New York Sash listing
    /// (349 Oriskany Blvd, Whitesboro, NY 13492).
    ///
    /// TODO before shipping the review prompt: fill this in from Google's
    /// Place ID Finder — https://developers.google.com/maps/documentation/places/web-service/place-id
    /// Leave it nil rather than guessing: a wrong ID sends customers to
    /// another business's review form.
    private static let googlePlaceID: String? = nil

    /// Opens Google's write-a-review dialog directly when the Place ID is
    /// known. Falls back to a Maps search for the listing, which still gets
    /// the customer there in two taps instead of zero — so the button works
    /// today and improves the moment the ID is filled in.
    static var googleReview: URL {
        if let googlePlaceID,
           let url = URL(string: "https://search.google.com/local/writereview?placeid=\(googlePlaceID)") {
            return url
        }
        return URL(string: "https://www.google.com/maps/search/?api=1&query=New+York+Sash+349+Oriskany+Blvd+Whitesboro+NY")!
    }
}
