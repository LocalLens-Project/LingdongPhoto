import SwiftUI

struct PiaogenceRootView: View {

    private var store = TicketStore.shared
    let onCreateTicket: () -> Void

    init(onCreateTicket: @escaping () -> Void = {}) {
        self.onCreateTicket = onCreateTicket
    }

    var body: some View {
        NavigationStack {
            TicketCollectionHome(onCreateTicket: onCreateTicket)
                .navigationDestination(for: CollectionRoute.self) { route in
                    CollectionTimelineView(source: route.timelineSource)
                }
        }
        .environment(store)
        .preferredColorScheme(.light)
    }
}
