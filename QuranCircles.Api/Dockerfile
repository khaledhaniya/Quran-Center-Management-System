FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["QuranCircles.Api/QuranCircles.Api.csproj", "QuranCircles.Api/"]
RUN dotnet restore "QuranCircles.Api/QuranCircles.Api.csproj"
COPY . .
WORKDIR "/src/QuranCircles.Api"
RUN dotnet publish "QuranCircles.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false
RUN cp quran.db /app/publish/quran.db || true

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENV DOTNET_USE_POLLING_FILE_WATCHER=true
ENV DOTNET_RUNNING_IN_CONTAINER=true
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 5070 10000 8080
ENTRYPOINT ["dotnet", "QuranCircles.Api.dll"]
