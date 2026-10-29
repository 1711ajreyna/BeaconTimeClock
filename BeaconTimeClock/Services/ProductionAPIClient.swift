import Foundation

enum ProductionAPIError: LocalizedError {
    case missingBaseURL
    case missingAuthentication
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "The Supabase Edge Function URL is not configured."
        case .missingAuthentication:
            return "A signed-in session is required."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .httpError(let status, let message):
            return "Server error \(status): \(message)"
        }
    }
}

@MainActor
final class ProductionAPIClient: WorkflowAPI {
    typealias TokenProvider = () async -> String?

    private let baseURL: URL?
    private let tokenProvider: TokenProvider
    private let session: URLSession

    init(
        baseURL: URL? = AppConfig.apiBaseURL,
        session: URLSession = .shared,
        tokenProvider: @escaping TokenProvider
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func fetchMyProfile() async throws -> UserProfile {
        try await sendWithoutBody(
            path: "my-profile",
            method: "GET",
            responseType: UserProfile.self
        )
    }

    func submitPunch(
        _ request: SubmitPunchRequest
    ) async throws -> SubmitPunchResponse {
        try await send(
            path: "submit-punch",
            method: "POST",
            body: request,
            responseType: SubmitPunchResponse.self
        )
    }

    func fetchMyShift() async throws -> MyShiftResponse {
        try await sendWithoutBody(
            path: "my-shift",
            method: "GET",
            responseType: MyShiftResponse.self
        )
    }

    func recordShiftEvent(
        _ request: RecordShiftEventRequest
    ) async throws -> RecordShiftEventResponse {
        try await send(
            path: "record-shift-event",
            method: "POST",
            body: request,
            responseType: RecordShiftEventResponse.self
        )
    }

    // MARK: - Named Shifts and Rosters

    func fetchShiftRoster() async throws -> ShiftRosterResponse {
        try await sendWithoutBody(
            path: "shift-roster", method: "GET",
            responseType: ShiftRosterResponse.self
        )
    }

    func createWorkShift(_ request: CreateWorkShiftRequest) async throws -> WorkShift {
        try await send(
            path: "create-work-shift", method: "POST", body: request,
            responseType: WorkShift.self
        )
    }

    func assignWorkShift(_ request: AssignWorkShiftRequest) async throws -> WorkShiftAssignment {
        try await send(
            path: "assign-work-shift", method: "POST", body: request,
            responseType: WorkShiftAssignment.self
        )
    }

    func removeWorkShiftAssignment(_ request: RemoveWorkShiftAssignmentRequest) async throws {
        let _: BasicAPIResponse = try await send(
            path: "remove-work-shift-assignment", method: "POST", body: request,
            responseType: BasicAPIResponse.self
        )
    }

    func fetchSupervisorSchedule() async throws -> SupervisorScheduleResponse {
        try await sendWithoutBody(
            path: "supervisor-schedule",
            method: "GET",
            responseType: SupervisorScheduleResponse.self
        )
    }

    func updateShiftSchedule(
        _ request: UpdateShiftScheduleRequest
    ) async throws -> UpdateShiftScheduleResponse {
        try await send(
            path: "update-shift-schedule",
            method: "POST",
            body: request,
            responseType: UpdateShiftScheduleResponse.self
        )
    }

    func fetchSupervisorDashboard()
    async throws -> SupervisorDashboard {
        try await sendWithoutBody(
            path: "supervisor-dashboard",
            method: "GET",
            responseType: SupervisorDashboard.self
        )
    }

    func fetchDepartmentTimesheet(
        timesheetID: UUID
    ) async throws -> DepartmentTimesheet {
        try await sendWithoutBody(
            path: "department-timesheet?timesheet_id=\(timesheetID.uuidString)",
            method: "GET",
            responseType: DepartmentTimesheet.self
        )
    }

    func adjustPunch(
        _ request: PunchAdjustmentRequest
    ) async throws -> PunchAdjustmentResponse {
        try await send(
            path: "adjust-punch",
            method: "POST",
            body: request,
            responseType: PunchAdjustmentResponse.self
        )
    }

    func approveDepartment(
        _ request: ApproveDepartmentRequest
    ) async throws -> ApproveDepartmentResponse {
        try await send(
            path: "approve-department",
            method: "POST",
            body: request,
            responseType: ApproveDepartmentResponse.self
        )
    }

    func resetDemoData() async {}

    // MARK: - HTTP

    private func makeRequest(
        path: String,
        method: String
    ) async throws -> URLRequest {
        guard let baseURL else {
            throw ProductionAPIError.missingBaseURL
        }

        guard let token = await tokenProvider(),
              !token.isEmpty else {
            throw ProductionAPIError.missingAuthentication
        }

        let parts = path.split(
            separator: "?",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )

        var url = baseURL.appendingPathComponent(
            String(parts[0])
        )

        if parts.count == 2 {
            guard var components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            ) else {
                throw ProductionAPIError.invalidResponse
            }

            components.percentEncodedQuery = String(parts[1])

            guard let composed = components.url else {
                throw ProductionAPIError.invalidResponse
            }

            url = composed
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )

        return request
    }

    private func send<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        method: String,
        body: RequestBody,
        responseType: ResponseBody.Type
    ) async throws -> ResponseBody {
        var request = try await makeRequest(
            path: path,
            method: method
        )

        request.httpBody = try DateFormatting
            .apiEncoder
            .encode(body)

        return try await perform(
            request,
            responseType: responseType
        )
    }

    private func sendWithoutBody<ResponseBody: Decodable>(
        path: String,
        method: String,
        responseType: ResponseBody.Type
    ) async throws -> ResponseBody {
        let request = try await makeRequest(
            path: path,
            method: method
        )

        return try await perform(
            request,
            responseType: responseType
        )
    }

    private func perform<ResponseBody: Decodable>(
        _ request: URLRequest,
        responseType: ResponseBody.Type
    ) async throws -> ResponseBody {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProductionAPIError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8)
                ?? "Unknown server error"
            throw ProductionAPIError.httpError(
                http.statusCode,
                message
            )
        }

        return try DateFormatting.apiDecoder.decode(
            ResponseBody.self,
            from: data
        )
    }
}
