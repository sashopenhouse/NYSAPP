import Foundation

enum NYSLinks {
    /// Google Place ID for the New York Sash listing
    /// (349 Oriskany Blvd, Whitesboro, NY 13492), supplied by the client.
    ///
    /// Confirm once by opening `googleReview` on a device signed in to a
    /// Google account: the review dialog names the business it will post to.
    /// That check can't be automated — Google redirects the write-review
    /// endpoint to sign-in, so no build step can assert this for us, and a
    /// wrong ID would send customers to another business's review form.
    private static let googlePlaceID: String? = "ChIJVx57XmRA2YkRDCCFJ8Ncoa4"

    /// Opens Google's write-a-review dialog directly when the Place ID is
    /// known, falling back to a Maps search for the listing if it's ever
    /// cleared, so the button always goes somewhere sensible.
    static var googleReview: URL {
        if let googlePlaceID,
           let url = URL(string: "https://search.google.com/local/writereview?placeid=\(googlePlaceID)") {
            return url
        }
        return URL(string: "https://www.google.com/maps/search/?api=1&query=New+York+Sash+349+Oriskany+Blvd+Whitesboro+NY")!
    }
}
