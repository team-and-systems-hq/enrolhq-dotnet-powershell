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

# Application status enum constants for convenience.
# Schools can rename statuses; read the labels a school actually uses with
# Get-EnrolHQReferenceData -Type ApplicationStatusSettings.
class EnrolHQStatus {
    static [int]$RegisterInterest   = -1
    static [int]$EnquiryOnline      = 0
    static [int]$EnquiryEvent       = 1
    static [int]$Eoi                = 2
    static [int]$Enrolment          = 3
    static [int]$Orientation        = 4
    static [int]$Community          = 5
    static [int]$Alumni             = 6
    static [int]$Trashed            = 7
    static [int]$Declined           = 8
    static [int]$Waitlist           = 9
    static [int]$ReservedOffer      = 10
    static [int]$NotProceeding      = 11
    static [int]$EnrolmentOffer     = 12
    static [int]$Interview          = 13
    static [int]$Pending            = 14
    static [int]$Custom1            = 15
    static [int]$Custom2            = 16
    static [int]$Custom3            = 17
    static [int]$Custom4            = 18
    static [int]$Custom5            = 19
    static [int]$Custom6            = 20
    static [int]$Custom7            = 21
    static [int]$Custom8            = 22
    static [int]$Custom9            = 23
    static [int]$Custom10           = 24
    static [int]$Custom11           = 25
    static [int]$Custom12           = 26
    static [int]$Custom13           = 27
    static [int]$Custom14           = 28
    static [int]$Custom15           = 29
    static [int]$Custom16           = 30
}
