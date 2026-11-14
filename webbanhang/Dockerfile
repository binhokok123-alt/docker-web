# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy csproj và restore dependencies trước (tận dụng Docker layer cache)
COPY ["webbanhang/webbanhang.csproj", "webbanhang/"]
RUN dotnet restore "webbanhang/webbanhang.csproj"

# Copy toàn bộ source và build
COPY . .
WORKDIR "/src/webbanhang"
RUN dotnet publish "webbanhang.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Stage 2: Runtime (image nhỏ hơn, không có SDK)
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

# Tạo thư mục uploads để lưu ảnh sản phẩm
RUN mkdir -p /app/wwwroot/uploads

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "webbanhang.dll"]
