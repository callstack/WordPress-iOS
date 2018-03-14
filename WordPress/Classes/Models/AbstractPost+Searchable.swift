import Foundation

extension Post: SearchableItemConvertable {
    var searchIdentifier: String? {
        guard let postID = postID, postID.intValue > 0 else {
            return nil
        }
        return postID.stringValue
    }

    var searchDomain: String? {
        if let dotComID = blog.dotComID, dotComID.intValue > 0 {
            return dotComID.stringValue
        } else {
            // This is a self-hosted site, set domain to the xmlrpc string
            return blog.xmlrpc
        }
    }

    var searchTitle: String? {
        guard let postTitle = postTitle else {
            return nil
        }

        return postTitle
    }

    var searchDescription: String? {
        let postPreview = contentPreviewForDisplay()
        guard !postPreview.isEmpty else {
            return String()
        }
        return postPreview
    }

    var searchKeywords: [String]? {
        return generateKeywords()
    }

    var searchLocalImageURL: URL? {
        return featuredImageURLForDisplay()
    }

    // MARK: - Helper Functions

    private func generateKeywords() -> [String]? {
        // Keywords defaults to tags
        guard hasTags() else {
           return generateKeywordsFromContent()
        }
        return tags?.arrayOfTags()
    }

    private func generateKeywordsFromContent() -> [String]? {
        var keywords: [String]? = nil
        if let postTitle = postTitle {
            // Try to generate some keywords from the title...
            keywords = postTitle.components(separatedBy: " ").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        } else if !contentPreviewForDisplay().isEmpty {
            // ...otherwise try to generate some keywords from the content preview
            keywords = contentPreviewForDisplay().components(separatedBy: " ").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        }
        return keywords
    }
}
