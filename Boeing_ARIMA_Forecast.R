# Install packages
install.packages(c("quantmod", "forecast", "tseries", "tidyverse", "gridExtra"))

# Libraries
library(quantmod)
library(forecast)
library(tseries)
library(tidyverse)
library(gridExtra)
library(timeDate)
library(lubridate)

# Event date and window
event_date <- as.Date("2025-06-12")
start_date <- event_date - 30  # 30 days before
end_date <- event_date + 30    # 30 days after

# Boeing stock data
getSymbols("BA", from = start_date, to = end_date, auto.assign = TRUE)

# Price data frame
ba_prices <- BA[, "BA.Adjusted"] %>% 
  as.data.frame() %>% 
  rownames_to_column("Date") %>% 
  mutate(Date = as.Date(Date)) %>% 
  arrange(Date)

# Convert adjusted prices to numeric vector for time series
price_vector <- as.numeric(ba_prices$BA.Adjusted)

# Create time series object (5 trading days per week approx)
ba_ts <- ts(price_vector, frequency = 5)

# Fit ARIMA model automatically
fit <- auto.arima(ba_ts)
summary(fit)

# Forecast next 7 trading days
forecast_days <- 7
forecasted <- forecast(fit, h = forecast_days)

# Generate next 7 business dates (skip weekends)
forecast_dates <- seq(from = max(ba_prices$Date) + 1, by = "1 day", length.out = 10)
forecast_dates <- forecast_dates[isBizday(timeDate(forecast_dates))][1:7]

# Add the last known real data point to the forecast df
last_point <- ba_prices %>%
  slice_tail(n = 1) %>%
  transmute(Date, Forecast = BA.Adjusted, Lo80 = NA, Hi80 = NA, Lo95 = NA, Hi95 = NA)

forecast_df <- data.frame(
  Date = forecast_dates,
  Forecast = as.numeric(forecasted$mean),
  Lo80 = as.numeric(forecasted$lower[, 1]),
  Hi80 = as.numeric(forecasted$upper[, 1]),
  Lo95 = as.numeric(forecasted$lower[, 2]),
  Hi95 = as.numeric(forecasted$upper[, 2])
)

# Combine last real price with forecast
forecast_df <- bind_rows(last_point, forecast_df)

# Plot combined historical and forecast prices
combined_plot <- ggplot() +
  geom_line(data = ba_prices, aes(x = Date, y = BA.Adjusted), color = "blue") +
  geom_line(data = forecast_df, aes(x = Date, y = Forecast), color = "darkgreen") +
  geom_ribbon(data = forecast_df, aes(x = Date, ymin = Lo95, ymax = Hi95), fill = "green", alpha = 0.2) +
  geom_ribbon(data = forecast_df, aes(x = Date, ymin = Lo80, ymax = Hi80), fill = "green", alpha = 0.4) +
  geom_vline(xintercept = as.numeric(event_date), color = "red", linetype = "dashed") +
  labs(title = "Boeing Stock Price & 7-Day Forecast After Air India Crash",
       subtitle = "Green bands show 80% and 95% confidence intervals",
       x = "Date", y = "Adjusted Closing Price") +
  theme_minimal()

# Show plot
print(combined_plot)



