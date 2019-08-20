import UIKit

class PostingActivityCell: UITableViewCell, NibLoadable {

    // MARK: - Properties

    @IBOutlet private var monthsStackView: UIStackView!
    @IBOutlet private var viewMoreLabel: UILabel!
    @IBOutlet private var legendView: UIView!

    @IBOutlet private var topSeparatorLine: UIView!
    @IBOutlet private var bottomSeparatorLine: UIView!

    @IBOutlet private var actionButton: UIButton!

    private typealias Style = WPStyleGuide.Stats
    private weak var siteStatsInsightsDelegate: SiteStatsInsightsDelegate?

    // MARK: - Init

    override func awakeFromNib() {
        super.awakeFromNib()
        applyStyles()
        addLegend()
    }

    func configure(withData monthsData: [[PostingStreakEvent]], andDelegate delegate: SiteStatsInsightsDelegate?, rowStatus: StoreFetchingStatus, hasCachedData: Bool) {
        siteStatsInsightsDelegate = delegate
        addMonths(monthsData: monthsData)
        animateGhostView(rowStatus == .loading && !hasCachedData)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        removeExistingMonths()
    }
}

// MARK: - Private Extension

private extension PostingActivityCell {
    func animateGhostView(_ animate: Bool) {
        actionButton.isGhostableDisabled = true
        actionButton.isHidden = animate
        if animate {
            startGhostAnimation()
        } else {
            stopGhostAnimation()
        }
    }

    func applyStyles() {
        viewMoreLabel.text = NSLocalizedString("View more", comment: "Label for viewing more posting activity.")
        viewMoreLabel.textColor = Style.actionTextColor
        Style.configureViewAsSeparator(topSeparatorLine)
        Style.configureViewAsSeparator(bottomSeparatorLine)
    }

    func addLegend() {
        let legend = PostingActivityLegend.loadFromNib()
        legendView.addSubview(legend)
    }

    func addMonths(monthsData: [[PostingStreakEvent]]) {
        for monthData in monthsData {
            let monthView = PostingActivityMonth.loadFromNib()
            monthView.configure(monthData: monthData)
            monthsStackView.addArrangedSubview(monthView)
        }
    }

    func removeExistingMonths() {
        monthsStackView.arrangedSubviews.forEach {
            monthsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    @IBAction func didTapViewMoreButton(_ sender: UIButton) {
        siteStatsInsightsDelegate?.showPostingActivityDetails?()
    }

}
