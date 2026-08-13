FROM mcr.microsoft.com/dotnet/sdk:10.0-preview AS build
WORKDIR /src
COPY ["QuranCircles.Api/QuranCircles.Api.csproj", "QuranCircles.Api/"]
RUN dotnet restore "QuranCircles.Api/QuranCircles.Api.csproj"
COPY . .
WORKDIR "/src/QuranCircles.Api"
RUN dotnet publish "QuranCircles.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0-preview AS final
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:5070
EXPOSE 5070
ENTRYPOINT ["dotnet", "QuranCircles.Api.dll"]
