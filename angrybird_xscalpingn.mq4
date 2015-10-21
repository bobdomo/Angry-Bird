#include "subroutines.mqh"

bool long_trade = FALSE;
bool new_orders_placed = FALSE;
bool short_trade = FALSE;
bool trade_now = FALSE;
double average_price = 0;
double buy_limit = 0;
double i_lots = 0;
double last_buy_price = 0;
double last_sell_price = 0;
double lot_multiplier = 0;
double price_target = 0;
double sell_limit = 0;
double slip = 3.0;
double tp_dist = 0;
int lotdecimal = 2;
int magic_number = 2222;
int error = 0;
int total = 0;
int time_difference = 0;
int previous_time = 0;
string name = "Ilan1.6";
string comment = "";
extern double macd_fast_ma = 12;
extern double macd_slow_ma = 26;
extern double macd_accel = 0.3;
extern double rsi_max = 70.0;
extern double rsi_min = 30.0;
extern int rsi_period = 14;
extern double exp_base = 1;
extern double lots = 0.01;
extern double takeprofit = 1300.0;

int IndicatorSignal() {
  if (iRSI(NULL, 0, rsi_period, PRICE_TYPICAL, 0) > rsi_max &&
      iMACD(NULL, 0, macd_fast_ma, macd_slow_ma, 9, PRICE_TYPICAL, MODE_MAIN, 0) > macd_accel) {
    return OP_SELL;
  }
  if (iRSI(NULL, 0, rsi_period, PRICE_TYPICAL, 0) < rsi_min &&
      iMACD(NULL, 0, macd_fast_ma, macd_slow_ma, 9, PRICE_TYPICAL, MODE_MAIN, 0) < -macd_accel) {
    return OP_BUY;
  }

  return -1;
}

int init() {
  last_buy_price = FindLastBuyPrice();
  last_sell_price = FindLastSellPrice();
  total = CountTrades();
  Update();

  /*###TODO###*/
  for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number) {
      if (OrderType() == OP_BUY) {
        long_trade = TRUE;
        short_trade = FALSE;
        break;
      }
      if (OrderType() == OP_SELL) {
        long_trade = FALSE;
        short_trade = TRUE;
        break;
      }
    }
  }

  average_price = 0;
  double Count = 0;
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number) {
      average_price += OrderOpenPrice() * OrderLots();
      Count += OrderLots();
    }
  }
  if (total > 0) average_price = NormalizeDouble(average_price / Count, Digits);

  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);

    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number) {
      if (OrderType() == OP_BUY)
        price_target = average_price + takeprofit * Point;
      if (OrderType() == OP_SELL)
        price_target = average_price - takeprofit * Point;
    }
  }

  return (0);
}

int deinit() { return (0); }

void Update() {
  buy_limit = Ask;
  RefreshRates();
  sell_limit = Bid;
  comment = name + "-" + total;
  time_difference = TimeCurrent() - Time[0];

  if (long_trade)
    tp_dist = (price_target - Bid) / Point;
  else if (short_trade)
    tp_dist = (Ask - price_target) / Point;
  else
    tp_dist = 0;

  if (tp_dist < takeprofit)
    lot_multiplier = 1;
  else
    lot_multiplier = NormalizeDouble(
        MathPow(exp_base, (tp_dist * total / takeprofit)), lotdecimal);

  Comment("Distance to Take Profit: " + tp_dist + "\nLot Multiplier: " +
          lot_multiplier + "\nTime Difference: " + time_difference +
          "\n Short Trade: " + short_trade + "\n Long Trade: " + long_trade);
}

int start() {
  Update();
  /* Causes trading to wait a certain amount of time after a new bar opens */
  if (IsTesting() || IsOptimization()) {
    if (error < 0) return (0);
    if (time_difference < 10 * 5) return (0);
    if (previous_time == Time[0]) return (0);
  } else {
    if (time_difference < 35 * 5) return (0);
    if (previous_time == Time[0]) return (0);
  }

  total = CountTrades();

  /* Alerts on error */
  if (error < 0) Alert("Error " + GetLastError());

  /* All the actions that occur when a trade is signaled */
  if (IndicatorSignal() > -1) {
    i_lots = GetLots();

    if (total == 0) {
      if (IndicatorSignal() == OP_BUY) {
        long_trade = TRUE;
        error = OpenPendingOrder(OP_BUY, i_lots, Ask, slip, Bid, 0, 0, comment,
                                 magic_number, 0, Lime);
        new_orders_placed = TRUE;
      }
      if (IndicatorSignal() == OP_SELL) {
        short_trade = TRUE;
        error = OpenPendingOrder(OP_SELL, i_lots, Bid, slip, Ask, 0, 0, comment,
                                 magic_number, 0, HotPink);
        new_orders_placed = TRUE;
      }
    } else {
      if (short_trade && Bid > last_sell_price + (takeprofit / 1) * Point)
        if (IndicatorSignal() == OP_SELL) {
          error = OpenPendingOrder(OP_SELL, i_lots, Bid, slip, Ask, 0, 0,
                                   comment, magic_number, 0, HotPink);
          new_orders_placed = TRUE;
        }
      if (long_trade && Ask < last_buy_price - (takeprofit / 1) * Point)
        if (IndicatorSignal() == OP_BUY) {
          error = OpenPendingOrder(OP_BUY, i_lots, Ask, slip, Bid, 0, 0,
                                   comment, magic_number, 0, Lime);

          new_orders_placed = TRUE;
        }
    }

    if (error < 0) return -1;
    total = CountTrades();
    last_buy_price = FindLastBuyPrice();
    last_sell_price = FindLastSellPrice();
  } else {
    if (total == 0) {
      short_trade = FALSE;
      long_trade = FALSE;
    }
  }

  /******************************************************************************************/
  /******************************************************************************************/
  if (new_orders_placed) {
    Update();
    previous_time = Time[0];
    average_price = 0;
    double Count = 0;

    for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
      error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number) {
        average_price += OrderOpenPrice() * OrderLots();
        Count += OrderLots();
      }
    }

    if (total > 0)
      average_price = NormalizeDouble(average_price / Count, Digits);

    for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
      error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);

      if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number) {
        if (OrderType() == OP_BUY)
          price_target = average_price + takeprofit * Point;
        if (OrderType() == OP_SELL)
          price_target = average_price - takeprofit * Point;

        error =
            OrderModify(OrderTicket(), NormalizeDouble(average_price, Digits),
                        NormalizeDouble(OrderStopLoss(), Digits),
                        NormalizeDouble(price_target, Digits), 0, Yellow);
      }

      new_orders_placed = FALSE;
    }
  }

  return (0);
}
