import UIKit

class StatsNoDataRow: UIView, NibLoadable, Accessible {

    // MARK: - Properties

    @IBOutlet weak var noDataLabel: UILabel!
    private let insightsNoDataLabel = NSLocalizedString("No data yet",
                                                        comment: "Text displayed when an Insights stat section has no data.")
    private let periodNoDataLabel = NSLocalizedString("No data for this period",
                                                      comment: "Text displayed when Period stat section has no data.")
    private let errorDataLabel = NSLocalizedString("An error occurred.",
                                                   comment: "Text displayed when stat section got an error.")

    // MARK: - Configure

    func configure(forType statType: StatType, rowStatus: StoreFetchingStatus = .idle) {
        WPStyleGuide.Stats.configureLabelAsNoData(noDataLabel)
        setText(for: statType, rowStatus: rowStatus)
        prepareForVoiceOver()
    }

    func prepareForVoiceOver() {
        isAccessibilityElement = true

        accessibilityLabel = noDataLabel.text
        accessibilityTraits = .staticText
    }
}

private extension StatsNoDataRow {
    func setText(for statType: StatType, rowStatus: StoreFetchingStatus) {
        switch rowStatus {
        case .success, .idle:
            noDataLabel.text = statType == .insights ? insightsNoDataLabel : periodNoDataLabel
        case .error:
            noDataLabel.text = errorDataLabel
        default:
            noDataLabel.text = ""
        }
    }
}
