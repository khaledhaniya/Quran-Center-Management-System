FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["QuranCircles.Api.csproj", "./"]
RUN dotnet restore "QuranCircles.Api.csproj"
COPY . .
RUN dotnet publish "QuranCircles.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:5070
EXPOSE 5070
ENTRYPOINT ["dotnet", "QuranCircles.Api.dll"]
