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
int num_of_trades = 0;
int error = 0;
int timeprev = 0;
int total = 0;
string name = "Ilan1.6";
string comment = "";
extern int rsi_max = 80.0;
extern int rsi_min = 20.0;
extern int rsi_period = 11;
extern double lots = 0.01;
extern double takeprofit = 1300.0;
extern double exp_base = 3;

int init() {
  Update();
  last_buy_price = FindLastBuyPrice();
  last_sell_price = FindLastSellPrice();
  return (0);
}

int deinit() { return (0); }

void Update() {
  buy_limit = Ask;
  RefreshRates();
  sell_limit = Bid;
  total = CountTrades();
  comment = name + "-" + total;

  /* ###TODO### */
  average_price = 0;
  double Count = 0;
  for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
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
  /* ###TODO### */

  if (long_trade) tp_dist = (price_target - Ask) / Point;
  else if (short_trade) tp_dist = (Bid - price_target) / Point;
  else tp_dist = 0;

  if (tp_dist < takeprofit)
    lot_multiplier = 1;
  else
    lot_multiplier = NormalizeDouble(MathPow(2, ((tp_dist * exp_base) / takeprofit) - exp_base), lotdecimal);

  Comment(
    "Distance to Take Profit: " + tp_dist +
    "\nLot Multiplier: " + lot_multiplier +
    "\nLast Buy: " + last_buy_price +
    "\nLast Sell: " + last_sell_price +
    "\nTrade Now: " + trade_now +
    "\nShort Trade: " + short_trade +
    "\nLong Trade: " + long_trade
    );
}

int start() {
  Update();
  /* Exits if we haven't moved forward any bars */
  if (timeprev == Time[0]) return (0);

  /* Alerts on error */
  if (error < 0) Alert("Error " + error);

  /* Cycles through any open orders */
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

  if (total < 1) {
    short_trade = FALSE;
    long_trade = FALSE;
    trade_now = FALSE;

    if (IsIndicatorHigh()) {
      short_trade = TRUE;
      trade_now = TRUE;
    }
    if (IsIndicatorLow()) {
      long_trade = TRUE;
      trade_now = TRUE;
    }
  } else if (total > 0) {
    if (short_trade && tp_dist > takeprofit)
      if (IsIndicatorHigh()) trade_now = TRUE;

    if (long_trade && tp_dist > takeprofit)
      if (IsIndicatorLow()) trade_now = TRUE;
  }

  if (trade_now) {
    i_lots = GetLots();
    num_of_trades = total;

    if (short_trade) {
      error = OpenPendingOrder(OP_SELL, i_lots, Bid, slip, Ask, 0, 0, comment,
                               magic_number, 0, HotPink);
    }
    if (long_trade) {
      error = OpenPendingOrder(OP_BUY, i_lots, Ask, slip, Bid, 0, 0, comment,
                               magic_number, 0, Lime);
    }

    timeprev = Time[0];
    trade_now = FALSE;
    new_orders_placed = TRUE;
    last_buy_price = FindLastBuyPrice();
    last_sell_price = FindLastSellPrice();
  }

  /******************************************************************************************/
  /******************************************************************************************/

  Update();
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

  if (new_orders_placed) {
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
