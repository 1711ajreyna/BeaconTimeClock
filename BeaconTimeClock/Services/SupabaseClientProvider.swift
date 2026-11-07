// FILE PURPOSE: Builds the Supabase SDK client from app configuration.
import Foundation
import Supabase

// This type groups related state and behavior under a clear responsibility.
enum SupabaseClientProvider {
    static func make() -> SupabaseClient? {
        guard !AppConfig.demoMode else {
            return nil
        }

        guard let url = AppConfig.supabaseURL,
              let key = AppConfig.supabasePublishableKey else {
            return nil
        }

        /// On Apple platforms supabase-swift persists Auth sessions by default
        /// in Keychain-backed local storage and automatically refreshes tokens.
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )
    }
}
