#if !COMMERCIAL_BUILD
import Combine
import Foundation



@MainActor
final class SupporterStore: ObservableObject {
    static let shared = SupporterStore()


    static let productID = ""

    @Published private(set) var product: Never?
    @Published private(set) var isLoading = false
    @Published private(set) var productLoadFailed = true
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?
    @Published private(set) var isFirstBatchUser = false
    @Published private(set) var firstBatchDownloadDate: Date?

    private init() {}

    func bootstrap() {}
    func refreshProductIfNeeded(showError: Bool = false) async {
        if showError {
            errorMessage = "暂时无法连接 App Store，请稍后重试。"
        }
    }
    func refreshFirstBatchStatus() {}
    func purchase() async {
        errorMessage = "暂时无法连接 App Store，请稍后重试。"
    }
    func restore() async {}
    func detectFirstBatchUser() async {}

    var firstBatchDownloadDateText: String? { nil }


    var displayPrice: String? { nil }
}
#endif
