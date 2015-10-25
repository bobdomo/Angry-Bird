
#include "subroutines.mqh"

bool long_trade = FALSE;
bool short_trade = FALSE;
bool trade_now = FALSE;
double i_lots = 0;
double last_buy_price = 0;
double last_sell_price = 0;
double lot_multiplier = 0;
double slip = 3.0;
double price_target = 0;
double average_price = 0;
int lotdecimal = 2;
int magic_number = 2222;
int error = 0;
int total = 0;
int time_difference = 0;
int previous_time = 0;
int tp_dist;
int pipstep = 0;
string name = "Ilan1.6";
string comment = "";
extern int rsi_max = 70.0;
extern int rsi_min = 30.0;
extern int rsi_period = 14;
extern int rsi_ma = 3;
double rsi_ma_result;
/*
extern int stoch_max = 80.0;
extern int stoch_min = 20.0;
extern int stoch_period = 5;
*/
extern int macd_fast = 3;
int macd_slow = 26;
extern double lots = 0.01;
extern double exp_base = 1.3;
extern double commission = 0.0055;
extern double takeprofit = 0;
double i_takeprofit = 0;

int init() {
  Update();
  if (total) {
    last_buy_price = FindLastBuyPrice();
    last_sell_price = FindLastSellPrice();
    UpdateAveragePrice();
    UpdateOpenOrders();
  }


  return (0);
}

int deinit() { return (0); }

int start() {
  /* Causes trading to wait a certain amount of time after a new bar opens */
  if (IsOptimization() || IsTesting()) {
    if (error < 0) {
      if (AccountFreeMargin() > 20) {
        OrderSend(Symbol(), OP_BUY, 0.1, Ask, slip, 0,
                  0, 0, magic_number, 0, 0);
        OrderSend(Symbol(), OP_SELL, 0.1, Bid, slip, 0,
                  0, 0, magic_number, 0, 0);
      }
      return (0);
    }

    time_difference = TimeCurrent() - Time[0];
    if (time_difference < 24 * 5) return (0);
    if (previous_time == Time[0]) return (0);
    Update();
  } else {
    if (error < 0) return (0);
    Update();
    if (time_difference < 50 * 5) return (0);
    if (previous_time == Time[0]) return (0);
  }

  /* All the actions that occur when a trade is signaled */
  if (IndicatorSignal() > -1) {
    i_lots = NormalizeDouble(lots * lot_multiplier, lotdecimal);

    if (total == 0) {
      if (IndicatorSignal() == OP_BUY) {
        long_trade = TRUE;
        error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                          magic_number, 0, clrLimeGreen);
      }
      if (IndicatorSignal() == OP_SELL) {
        short_trade = TRUE;
        error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                          magic_number, 0, clrHotPink);
      }
      NewOrdersPlaced();
    } else {
      if (short_trade && Bid > last_sell_price + pipstep * Point)
        if (IndicatorSignal() == OP_SELL) {
          error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                            magic_number, 0, clrHotPink);
          NewOrdersPlaced();
        }
      if (long_trade && Ask < last_buy_price - pipstep * Point)
        if (IndicatorSignal() == OP_BUY) {
          error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                            magic_number, 0, clrLimeGreen);
          NewOrdersPlaced();
        }
    }
  }

  return (0);
}

void NewOrdersPlaced() {
  if (error < 0) return (0);

  previous_time = Time[0];
  last_buy_price = FindLastBuyPrice();
  last_sell_price = FindLastSellPrice();
  total = CountTrades();
  UpdateAveragePrice();
  UpdateOpenOrders();
}

void Update() {
  time_difference = TimeCurrent() - Time[0];
  total = CountTrades();

  /* Usually runs when orders are gone due to take profit */
  if (total == 0) {
    short_trade = FALSE;
    long_trade = FALSE;
    price_target = 0;
    average_price = 0;
  }

  /* Alerts on error */
  if (error < 0) Alert("Error " + GetLastError());

  if (short_trade) {
    tp_dist = (Bid - price_target) / Point;
  }
  else if (long_trade) {
    tp_dist = (price_target - Ask) / Point;
  }
  else
    tp_dist = 0;

  i_takeprofit = NormalizeDouble(takeprofit + (Bid * commission) / Point, 0);

  pipstep = i_takeprofit *
            MathAbs(iMACD(NULL, 0, macd_fast, macd_slow, 9, PRICE_TYPICAL, MODE_MAIN, 0));

  if (total > 0)
    lot_multiplier =
        NormalizeDouble(MathPow(exp_base, (tp_dist * total / i_takeprofit)), lotdecimal);
  else
    lot_multiplier = 1;

  Comment(
          "\nPipstep: " + pipstep +
          "\nLot Multiplier: " + lot_multiplier +
          "\nTime passed: " + time_difference +
          "\nAverage Price: " + average_price +
          "\nTake Profit: " + i_takeprofit +
          "\nTake Profit Distance: " + tp_dist +
          "\nRSI MA: " + rsi_ma_result
          );
}

void UpdateAveragePrice() {
  average_price = 0;
  double count = 0;

  for (int i = 0; i < total; ++i) {
    error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number) {
      average_price += OrderOpenPrice() * OrderLots();
      count += OrderLots();
    }
  }

  average_price /= total;
  count /= total;
  average_price = NormalizeDouble(average_price / count, Digits);
}

void UpdateOpenOrders() {
  for (int i = OrdersTotal() - 1; i >= 0; i--) {
    error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number) {
      if (OrderType() == OP_BUY) {
        price_target =
            NormalizeDouble(average_price + (i_takeprofit * Point), Digits);
        short_trade = FALSE;
        long_trade = TRUE;
      }
      if (OrderType() == OP_SELL) {
        price_target =
            NormalizeDouble(average_price - (i_takeprofit * Point), Digits);
        short_trade = TRUE;
        long_trade = FALSE;
      }

      error = OrderModify(OrderTicket(), NULL,
                          NormalizeDouble(OrderStopLoss(), Digits),
                          NormalizeDouble(price_target, Digits), 0, Yellow);
    }
  }
}

int IndicatorSignal() {
  rsi_ma_result = 0;
  for (int i = 0; i < rsi_ma; i++) {
    rsi_ma_result += iRSI(NULL, 0, rsi_period, PRICE_TYPICAL, i);
  }
  
  rsi_ma_result = rsi_ma_result / rsi_ma;

  if (rsi_ma_result > rsi_max)
    return OP_SELL;
  if (rsi_ma_result < rsi_min)
    return OP_BUY;
    /*
  if (iStochastic(NULL, 0, stoch_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 0) < stoch_max &&
      iStochastic(NULL, 0, stoch_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 1) > stoch_max)
    return OP_SELL;
  if (iStochastic(NULL, 0, stoch_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 0) > stoch_min &&
      iStochastic(NULL, 0, stoch_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 1) < stoch_min)
    return OP_BUY;
    */
  return (-1);
}
