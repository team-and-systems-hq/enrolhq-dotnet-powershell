# Connection state object stored in module scope
class EnrolHQConnection {
    [string]$BaseUrl
    [string]$ApiToken
    [string]$AccessToken
    [int]$TimeoutSeconds = 30
    [int]$MaxRetries = 3
    [bool]$IsConnected = $false

    EnrolHQConnection([string]$baseUrl, [string]$apiToken) {
        $this.BaseUrl = $baseUrl.TrimEnd('/') + '/'
        $this.ApiToken = $apiToken
    }

    [string] BuildUrl([string]$endpoint) {
        return $this.BaseUrl + $endpoint.TrimStart('/')
    }

    [void] RefreshToken() {
        $url = $this.BuildUrl('accounts/refresh/')
        $headers = @{ 'Authorization' = "Token $($this.ApiToken)" }

        try {
            $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers `
                -TimeoutSec $this.TimeoutSeconds -ErrorAction Stop
        }
        catch {
            throw "Token refresh failed: $($_.Exception.Message)"
        }

        if (-not $response.access_token) {
            throw "Token refresh response missing 'access_token' field"
        }

        $this.AccessToken = $response.access_token
        $this.IsConnected = $true
    }

    [hashtable] GetAuthHeaders() {
        if (-not $this.AccessToken) {
            $this.RefreshToken()
        }
        return @{ 'Authorization' = "Token $($this.AccessToken)" }
    }
}

# Application status enum constants for convenience
class EnrolHQStatus {
    static [int]$Archived           = -1
    static [int]$EnquiryOnline      = 0
    static [int]$EnquiryManual      = 1
    static [int]$Eoi                = 2
    static [int]$Interview          = 3
    static [int]$Enrolment          = 4
    static [int]$OfferEnrolment     = 5
    static [int]$Accepted           = 6
    static [int]$Enrolled           = 7
    static [int]$Deferred           = 8
    static [int]$Waitlisted         = 9
    static [int]$WithdrawnByParent  = 10
    static [int]$DeclinedBySchool   = 11
    static [int]$Closed             = 12
    static [int]$EnquiryEvent       = 13
    static [int]$EnquiryTour        = 14
    static [int]$EnquiryReferred    = 15
    static [int]$EnquiryPhone       = 16
    static [int]$EnquiryWalkIn      = 17
    static [int]$Reserved           = 18
    static [int]$OfferReservedPlace = 19
    static [int]$AcceptedReservedPlace = 20
    static [int]$DeclinedByParent   = 21
    static [int]$CancelledBySchool  = 22
}
