import UIKit

class TwoColumnCell: UITableViewCell, NibLoadable {

    // MARK: - Properties

    @IBOutlet weak var topSeparatorLine: UIView!
    @IBOutlet weak var rowsStackView: UIStackView!
    @IBOutlet weak var viewMoreView: UIView!
    @IBOutlet weak var viewMoreLabel: UILabel!
    @IBOutlet weak var bottomSeparatorLine: UIView!
    @IBOutlet weak var rowsStackViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewMoreHeightConstraint: NSLayoutConstraint!

    private typealias Style = WPStyleGuide.Stats
    private var dataRows = [StatsTwoColumnRowData]()
    private var statSection: StatSection?
    private weak var siteStatsInsightsDelegate: SiteStatsInsightsDelegate?
    private var rowStatus: StoreFetchingStatus = .loading

    // MARK: - View

    override func awakeFromNib() {
        super.awakeFromNib()
        applyStyles()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        removeRowsFromStackView(rowsStackView)
    }

    func configure(dataRows: [StatsTwoColumnRowData], statSection: StatSection, siteStatsInsightsDelegate: SiteStatsInsightsDelegate?, rowStatus: StoreFetchingStatus) {
        self.dataRows = dataRows
        self.statSection = statSection
        self.siteStatsInsightsDelegate = siteStatsInsightsDelegate
        self.rowStatus = rowStatus
        addRows()
        toggleViewMore()
    }
}

// MARK: - Private Extension

private extension TwoColumnCell {

    func applyStyles() {
        viewMoreLabel.text = NSLocalizedString("View more", comment: "Label for viewing more stats.")
        viewMoreLabel.textColor = Style.actionTextColor
        Style.configureViewAsSeparator(topSeparatorLine)
        Style.configureViewAsSeparator(bottomSeparatorLine)
    }

    func addRows() {
        switch (dataRows.isEmpty, rowStatus) {
        case (true, .loading):
            let row = StatsTwoColumnRow.loadFromNib()
            row.startGhostAnimation()
            rowsStackView.addArrangedSubview(row)
        case (true, let status) where status != .loading:
            let row = StatsNoDataRow.loadFromNib()
            row.configure(forType: .insights, rowStatus: status)
            rowsStackView.addArrangedSubview(row)
        default:
            for dataRow in dataRows {
                let row = StatsTwoColumnRow.loadFromNib()
                row.configure(rowData: dataRow)
                rowsStackView.addArrangedSubview(row)
            }
        }
    }

    func toggleViewMore() {
        let showViewMore = !dataRows.isEmpty && statSection == .insightsAnnualSiteStats
        viewMoreView.isHidden = !showViewMore
        rowsStackViewBottomConstraint.constant = showViewMore ? viewMoreHeightConstraint.constant : 0
    }

    @IBAction func didTapViewMore(_ sender: UIButton) {
        guard let statSection = statSection else {
            return
        }

        captureAnalyticsEventsFor(statSection)
        siteStatsInsightsDelegate?.viewMoreSelectedForStatSection?(statSection)
    }

    // MARK: - Analytics support

    func captureAnalyticsEventsFor(_ statSection: StatSection) {
        if let event = statSection.analyticsViewMoreEvent {
            captureAnalyticsEvent(event)
        }
    }

    func captureAnalyticsEvent(_ event: WPAnalyticsStat) {
        if let blogIdentifier = SiteStatsInformation.sharedInstance.siteID {
            WPAppAnalytics.track(event, withBlogID: blogIdentifier)
        } else {
            WPAppAnalytics.track(event)
        }
    }

}

// MARK: - Analytics support

private extension StatSection {
    var analyticsViewMoreEvent: WPAnalyticsStat? {
        switch self {
        case .insightsAnnualSiteStats:
            return .statsViewMoreTappedThisYear
        default:
            return nil
        }
    }
}
