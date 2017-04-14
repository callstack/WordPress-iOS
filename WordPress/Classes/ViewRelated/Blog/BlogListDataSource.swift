import CoreData
import Foundation
import UIKit
import WordPressShared

private protocol BlogListDataSourceMapper {
    func map(_ data: [Blog]) -> [[Blog]]
}

private struct BrowsingWithRecentDataSourceMapper: BlogListDataSourceMapper {
    func map(_ data: [Blog]) -> [[Blog]] {
        let service = RecentSitesService()
        let recentSiteUrls = service.allRecentSites
        let visible = data.filter({ $0.visible })
        let allRecent = recentSiteUrls.flatMap({ url in
            return visible.first(where: { $0.url == url })
        })
        let recent = Array(allRecent.prefix(service.maxSiteCount))
        let other = visible.filter({ blog in
            return !recent.contains(blog)
        })
        return [recent, other]
    }
}

private struct BrowsingDataSourceMapper: BlogListDataSourceMapper {
    func map(_ data: [Blog]) -> [[Blog]] {
        return [data.filter({ $0.visible })]
    }
}

private struct EditingDataSourceMapper: BlogListDataSourceMapper {
    func map(_ data: [Blog]) -> [[Blog]] {
        return [data.filter({ blog in
            blog.supports(.visibility)
        })]
    }
}

private struct SearchingDataSourceMapper: BlogListDataSourceMapper {
    let query: String

    func map(_ data: [Blog]) -> [[Blog]] {
        guard let query = query.nonEmptyString() else {
            return [data]
        }
        return [data.filter({ blog in
            let nameContainsQuery = blog.settings?.name.map({ $0.localizedCaseInsensitiveContains(query) }) ?? false
            let urlContainsQuery = blog.url.map({ $0.localizedCaseInsensitiveContains(query) }) ?? false
            return nameContainsQuery || urlContainsQuery
        })]
    }
}

class BlogListDataSource: NSObject {
    override init() {
        super.init()
        // We can't decide if we're using recent sites until the results controller
        // is configured and we have a list of blogs, so we have to update this right
        // after initializing the data source.
        updateMode()
        resultsController.delegate = self
    }

    // MARK: - Configuration

    let recentSitesMinCount = 11

    // MARK: - Inputs

    var editing: Bool = false {
        didSet {
            updateMode()
        }
    }

    var searching: Bool = false {
        didSet {
            updateMode()
        }
    }

    var searchQuery: String = "" {
        didSet {
            updateMode()
        }
    }

    var selecting: Bool = false {
        didSet {
            if selecting != oldValue {
                dataChanged?()
            }
        }
    }

    var selectedBlogId: NSManagedObjectID? = nil {
        didSet {
            if selectedBlogId != oldValue {
                dataChanged?()
            }
        }
    }

    var account: WPAccount? = nil {
        didSet {
            if account != oldValue {
                dataChanged?()
            }
        }
    }

    // MARK: - Outputs

    var dataChanged: (() -> Void)?

    var visibilityChanged: ((Blog, Bool) -> Void)?

    @objc(blogAtIndexPath:)
    func blog(at indexPath: IndexPath) -> Blog {
        return sections[indexPath.section][indexPath.row]
    }

    @objc(indexPathForBlog:)
    func indexPath(for blog: Blog) -> IndexPath? {
        for (sectionIndex, section) in sections.enumerated() {
            for (rowIndex, row) in section.enumerated() {
                if row == blog {
                    return IndexPath(row: rowIndex, section: sectionIndex)
                }
            }
        }
        return nil
    }

    var allBlogsCount: Int {
        return allBlogs.count
    }

    var displayedBlogsCount: Int {
        return sections.reduce(0, { result, section in
            result + section.count
        })
    }

    var visibleBlogsCount: Int {
        return allBlogs.filter({ $0.visible }).count
    }

    // MARK: - Internal properties

    fileprivate let resultsController: NSFetchedResultsController<Blog> = {
        let context = ContextManager.sharedInstance().mainContext
        let request = NSFetchRequest<Blog>(entityName: NSStringFromClass(Blog.self))
        request.sortDescriptors = [
            NSSortDescriptor(key: "accountForDefaultBlog.userID", ascending: false),
            NSSortDescriptor(key: "settings.name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        do {
            try controller.performFetch()
        } catch {
            fatalError("Error fetching blogs list: \(error)")
        }
        return controller
    }()

    fileprivate var mode: Mode = .browsing {
        didSet {
            if mode != oldValue {
                dataChanged?()
            }
        }
    }
}

// MARK: - Mode

private extension BlogListDataSource {
    enum Mode: Equatable {
        case browsing
        case browsingWithRecent
        case editing
        case searching(String)

        var mapper: BlogListDataSourceMapper {
            switch self {
            case .browsing:
                return BrowsingDataSourceMapper()
            case .browsingWithRecent:
                return BrowsingWithRecentDataSourceMapper()
            case .editing:
                return EditingDataSourceMapper()
            case .searching(let query):
                return SearchingDataSourceMapper(query: query)
            }
        }

        static func == (lhs: Mode, rhs: Mode) -> Bool {
            switch (lhs, rhs) {
            case (.browsing, .browsing),
                 (.browsingWithRecent, .browsingWithRecent),
                 (.editing, .editing):
                return true
            case let (.searching(lquery), .searching(rquery)):
                return lquery == rquery
            default:
                return false
            }
        }
    }

    func updateMode() {
        // Extracted this into its own function so the compiler can enforce that
        // a mode must be returned
        mode = modeForCurrentState()
    }

    func modeForCurrentState() -> Mode {
        if editing {
            return .editing
        }
        if searching {
            return .searching(searchQuery)
        }
        if visibleBlogsCount > recentSitesMinCount {
            return .browsingWithRecent
        }
        return .browsing
    }
}

// MARK: - Data

private extension BlogListDataSource {
    var sections: [[Blog]] {
        return mode.mapper.map(allBlogs)
    }

    var allBlogs: [Blog] {
        guard let blogs = resultsController.fetchedObjects else {
            return []
        }
        guard let account = account else {
            return blogs
        }
        return blogs.filter({ $0.account == account })
    }
}

// MARK: - Results Controller Delegate

extension BlogListDataSource: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // TODO: only propagate if the filtered data changed
        dataChanged?()
    }
}

// MARK: - UITableView Data Source

extension BlogListDataSource: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let blog = self.blog(at: indexPath)
        guard let cell = tableView.dequeueReusableCell(withIdentifier: WPBlogTableViewCell.reuseIdentifier()) as? WPBlogTableViewCell else {
            fatalError("Failed to get a blog cell")
        }
        let displayURL = blog.displayURL as? String ?? ""
        if let name = blog.settings?.name?.nonEmptyString() {
            cell.textLabel?.text = name
            cell.detailTextLabel?.text = displayURL
        } else {
            cell.textLabel?.text = displayURL
            cell.detailTextLabel?.text = nil
        }
        if selecting {
            if selectedBlogId == blog.objectID {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        } else {
            cell.accessoryType = .disclosureIndicator
        }
        cell.selectionStyle = tableView.isEditing ? .none : .blue
        cell.imageView?.layer.borderColor = UIColor.white.cgColor
        cell.imageView?.layer.borderWidth = 1.5
        cell.imageView?.setImageWithSiteIcon(blog.icon)
        cell.visibilitySwitch?.accessibilityIdentifier = String(format: "Switch-Visibility-%@", blog.settings?.name ?? "")
        cell.visibilitySwitch?.isOn = blog.visible
        cell.visibilitySwitchToggled = { [visibilityChanged] cell in
            guard let isOn = cell.visibilitySwitch?.isOn else {
                return
            }
            visibilityChanged?(blog, isOn)
        }

        if !blog.visible {
            cell.textLabel?.textColor = WPStyleGuide.readGrey()
        }

        WPStyleGuide.configureTableViewBlogCell(cell)

        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}
