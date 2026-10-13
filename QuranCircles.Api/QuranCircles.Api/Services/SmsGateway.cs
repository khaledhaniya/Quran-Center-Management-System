using System.Net.Http.Headers;

namespace QuranCircles.Api.Services;

public class SmsGateway(HttpClient client, IConfiguration configuration)
{
    public bool IsConfigured => Uri.TryCreate(configuration["Sms:GatewayUrl"], UriKind.Absolute, out var url)
        && url.Scheme == "https" && !string.IsNullOrWhiteSpace(configuration["Sms:ApiToken"]);

    public async Task<bool> SubmitAsync(IReadOnlyList<string> recipients, string message, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return false;
        using var request = new HttpRequestMessage(HttpMethod.Post, configuration["Sms:GatewayUrl"]);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", configuration["Sms:ApiToken"]);
        request.Content = JsonContent.Create(new { recipients, message });
        using var response = await client.SendAsync(request, cancellationToken);
        return response.IsSuccessStatusCode;
    }
}
