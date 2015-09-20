uchar bit_flags = 0;
// bool trade_now          = FALSE;  // bit flag 00000010
bool short_trade = FALSE;        // bit flag 00000100
bool long_trade = FALSE;         // bit flag 00001000
bool new_orders_placed = FALSE;  // bit flag 00010000
bool use_equity_stop = FALSE;    // bit flag 00100000
bool use_timeout = FALSE;        // bit flag 01000000
bool use_trailing_stop = FALSE;  // bit flag 10000000
double AccntEquityHighAmt = 0;
double AveragePrice = 0;
double BuyLimit = 0;
double BuyTarget = 0;
double Drop = 500;
double iLots = 0;
double last_buy_price = 0;
double last_sell_price = 0;
double MaxTradeOpenHours = 48.0;
double PrevEquity = 0;
double PriceTarget = 0;
double RsiMaximum = 70.0;
double RsiMinimum = 30.0;
double SellLimit = 0;
double SellTarget = 0;
double slip = 3.0;
double Spread = 0;
double start_equity = 0;
double Stoploss = 500.0;
double Stopper = 0.0;
double TotalEquityRisk = 20.0;
double TrailStart = 10.0;
extern bool dynamic_pips = TRUE;
extern double lot_exponent = 2;
extern double lots = 0.01;
extern double take_profit = 1500.0;
extern double trail_stop = 9000;
extern int max_trades = 5;
extern int min_pip_height = 1500;
extern int pip_divisor = 2;
extern int pip_memory = 120;
int count = 0;
int expiration = 0;
int lotdecimal = 2;
int MagicNumber = 2222;
int NumOfTrades = 0;
int PipStep = 0;
int ticket = 0;
int timeprev = 0;
int total = 0;
const string EAName = "Ilan1.6";

void Debug() { Comment("Bit flags: " + bit_flags); }

// Updates info that trades are based on like indicators and extremes
int UpdateProperties() {
  // Updates how much of a swing needs to happen based on recent history
  if (dynamic_pips) {

    // Calculates highest and lowest price from last bar to X bars ago
    double hival = High[iHighest(NULL, 0, MODE_HIGH, pip_memory, 1)];
    double loval = Low[iLowest(NULL, 0, MODE_LOW, pip_memory, 1)];

    // Calculates pips for spread between orders
    PipStep = NormalizeDouble((hival - loval) / pip_divisor / Point, 0);

    // If dynamic pips fail, this assigns pips extreme value
    if (PipStep < min_pip_height / pip_divisor)
      PipStep = NormalizeDouble(min_pip_height / pip_divisor, 0);
    else if (PipStep > min_pip_height * pip_divisor)
      PipStep = NormalizeDouble(min_pip_height * pip_divisor, 0);
    else
      PipStep = min_pip_height;
  }

  // This trailing stop needs work
  if (use_trailing_stop) TrailingAlls(TrailStart, trail_stop, AveragePrice);

  // Kills all open trades if the price crashes based on the Commodity Channel
  if ((iCCI(NULL, 15, 55, 0, 0) > Drop && short_trade) ||
      (iCCI(NULL, 15, 55, 0, 0) < (-Drop) && long_trade)) {
    CloseThisSymbolAll();
    Print("Closed All due to Timeout");
  }

  return 0;
}

// Sets new trades and updates previous trades based on new ones
void UpdateTrades() {
  total = CountTrades();

  for (count = OrdersTotal() - 1; count >= 0; count--) {
    if (!OrderSelect(count, SELECT_BY_POS, MODE_TRADES)) CheckError();
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;

    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
      if (OrderType() == OP_BUY) {
        long_trade = TRUE;
        short_trade = FALSE;
        break;
      }
    }
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
      if (OrderType() == OP_SELL) {
        long_trade = FALSE;
        short_trade = TRUE;
        break;
      }
    }
  }

  if (total > 0 && total <= max_trades) {
    RefreshRates();
    last_buy_price = FindLastBuyPrice();
    last_sell_price = FindLastSellPrice();

    if (long_trade && last_buy_price - Ask >= PipStep * Point)
      bit_flags |= (1 << 2);
    if (short_trade && Bid - last_sell_price >= PipStep * Point)
      bit_flags |= (1 << 2);
  }

  if (total < 1) {
    // Enables the trade_now flag
    bit_flags |= (1 << 2);

    short_trade = FALSE;
    long_trade = FALSE;
    start_equity = AccountEquity();
  }

  // Checks if the trade_now flag is set
  if ((bit_flags & (1 << 2)) != 0) {
    last_buy_price = FindLastBuyPrice();
    last_sell_price = FindLastSellPrice();

    if (short_trade) {
      NumOfTrades = total;
      iLots = NormalizeDouble(lots * MathPow(lot_exponent, NumOfTrades),
                              lotdecimal);
      RefreshRates();
      ticket = OpenPendingOrder(1, iLots, Bid, slip, Ask, 0, 0,
                                EAName + "-" + NumOfTrades + "-" + PipStep,
                                MagicNumber, 0, HotPink);
      last_sell_price = FindLastSellPrice();
      // Trading is done, switches the trade_now flag
      bit_flags ^= (1 << 2);
      new_orders_placed = TRUE;
    } else if (long_trade) {
      NumOfTrades = total;
      iLots = NormalizeDouble(lots * MathPow(lot_exponent, NumOfTrades),
                              lotdecimal);
      ticket = OpenPendingOrder(0, iLots, Ask, slip, Bid, 0, 0,
                                EAName + "-" + NumOfTrades + "-" + PipStep,
                                MagicNumber, 0, Lime);
      last_buy_price = FindLastBuyPrice();
      bit_flags ^= (1 << 2);
      new_orders_placed = TRUE;
    }
  }
  if (ticket < 0) CheckError();

  if ((bit_flags & (1 << 2)) != 0 && total < 1) {
    double previous_close = iClose(Symbol(), 0, 2);
    double current_close = iClose(Symbol(), 0, 1);
    SellLimit = Bid;
    BuyLimit = Ask;

    if (!short_trade && !long_trade) {
      NumOfTrades = total;
      iLots = NormalizeDouble(lots * MathPow(lot_exponent, NumOfTrades),
                              lotdecimal);

      if (previous_close > current_close) {
        if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) > RsiMinimum) {
          ticket = OpenPendingOrder(1, iLots, SellLimit, slip, SellLimit, 0, 0,
                                    EAName + "-" + NumOfTrades, MagicNumber, 0,
                                    HotPink);
          last_buy_price = FindLastBuyPrice();
          new_orders_placed = TRUE;
        }
      } else {
        if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) < RsiMaximum) {
          ticket = OpenPendingOrder(0, iLots, BuyLimit, slip, BuyLimit, 0, 0,
                                    EAName + "-" + NumOfTrades, MagicNumber, 0,
                                    Lime);
          last_sell_price = FindLastSellPrice();
          new_orders_placed = TRUE;
        }
      }
      if (ticket < 0)
        CheckError();
      else
        expiration = TimeCurrent() + 60.0 * (60.0 * MaxTradeOpenHours);

      bit_flags ^= (1 << 2);
    }
  }

  // I would like to change these last few routines of price calculation
  total = CountTrades();
  AveragePrice = 0;
  double Count = 0;

  for (count = OrdersTotal() - 1; count >= 0; count--) {
    if (!OrderSelect(count, SELECT_BY_POS, MODE_TRADES)) CheckError();
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
      if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
        AveragePrice += OrderOpenPrice() * OrderLots();
        Count += OrderLots();
      }
    }
  }

  if (total > 0) AveragePrice = NormalizeDouble(AveragePrice / Count, Digits);

  if (new_orders_placed) {
    for (count = OrdersTotal() - 1; count >= 0; count--) {
      if (!OrderSelect(count, SELECT_BY_POS, MODE_TRADES)) CheckError();
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
        continue;
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
        if (OrderType() == OP_BUY) {
          PriceTarget = AveragePrice + take_profit * Point;
          BuyTarget = PriceTarget;
          Stopper = AveragePrice - Stoploss * Point;
        }
      }
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
        if (OrderType() == OP_SELL) {
          PriceTarget = AveragePrice - take_profit * Point;
          SellTarget = PriceTarget;
          Stopper = AveragePrice + Stoploss * Point;
        }
      }
    }
  }

  if (new_orders_placed) {
    for (count = OrdersTotal() - 1; count >= 0; count--) {
      if (!OrderSelect(count, SELECT_BY_POS, MODE_TRADES)) CheckError();
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
        continue;
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
        if (!OrderModify(OrderTicket(), NormalizeDouble(AveragePrice, Digits),
                         NormalizeDouble(OrderStopLoss(), Digits),
                         NormalizeDouble(PriceTarget, Digits), 0, Yellow)) {
          CheckError();
        }
        new_orders_placed = FALSE;
      }
    }
  }
}

// This works akin to a state machine with lots of if statements
int start() {
  // Returns if the current bar is the same one as the last run
  if (timeprev == Time[0]) return (0);

  // Counts execution time
  int start_time = GetMicrosecondCount();
  UpdateProperties();
  UpdateTrades();
  Comment((GetMicrosecondCount() - start_time) + " microseconds");

  // Sets the time this loop finishes to avoid running it again on the same data
  timeprev = Time[0];
  return 0;
}

int init() {
  Spread = MarketInfo(Symbol(), MODE_SPREAD) * Point;
  return (0);
}
int deinit() { return (0); }

int CountTrades() {
  count = 0;
  for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
    if (!OrderSelect(trade, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
  }
  return (count);
}

void CloseThisSymbolAll() {
  for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
    if (!OrderSelect(trade, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    }
    if (OrderSymbol() == Symbol()) {
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
        if (OrderType() == OP_BUY)
          if (!OrderClose(OrderTicket(), OrderLots(), Bid, slip, Blue)) {
            CheckError();
          }
        if (OrderType() == OP_SELL)
          if (!OrderClose(OrderTicket(), OrderLots(), Ask, slip, Red)) {
            CheckError();
          }
      }
      Sleep(1000);
    }
  }
}

int OpenPendingOrder(int pType, double pLots, double pLevel, int sp, double pr,
                     int sl, int tp, string pComment, int pMagic, int pDatetime,
                     color pColor) {
  int c = 0;
  int NumberOfTries = 100;
  switch (pType) {
    case 2:
      for (c = 0; c < NumberOfTries; c++) {
        ticket = OrderSend(Symbol(), OP_BUYLIMIT, pLots, pLevel, sp,
                           StopLong(pr, sl), TakeLong(pLevel, tp), pComment,
                           pMagic, pDatetime, pColor);
        if (!CheckError()) break;
      }
      break;
    case 4:
      for (c = 0; c < NumberOfTries; c++) {
        ticket = OrderSend(Symbol(), OP_BUYSTOP, pLots, pLevel, sp,
                           StopLong(pr, sl), TakeLong(pLevel, tp), pComment,
                           pMagic, pDatetime, pColor);
        if (!CheckError()) break;
      }
      break;
    case 0:
      for (c = 0; c < NumberOfTries; c++) {
        RefreshRates();
        ticket =
            OrderSend(Symbol(), OP_BUY, pLots, NormalizeDouble(Ask, Digits), sp,
                      NormalizeDouble(StopLong(Bid, sl), Digits),
                      NormalizeDouble(TakeLong(Ask, tp), Digits), pComment,
                      pMagic, pDatetime, pColor);
        if (!CheckError()) break;
      }
      break;
    case 3:
      for (c = 0; c < NumberOfTries; c++) {
        ticket = OrderSend(Symbol(), OP_SELLLIMIT, pLots, pLevel, sp,
                           StopShort(pr, sl), TakeShort(pLevel, tp), pComment,
                           pMagic, pDatetime, pColor);
        if (!CheckError()) break;
      }
      break;
    case 5:
      for (c = 0; c < NumberOfTries; c++) {
        ticket = OrderSend(Symbol(), OP_SELLSTOP, pLots, pLevel, sp,
                           StopShort(pr, sl), TakeShort(pLevel, tp), pComment,
                           pMagic, pDatetime, pColor);
        if (!CheckError()) break;
      }
      break;
    case 1:
      for (c = 0; c < NumberOfTries; c++) {
        ticket =
            OrderSend(Symbol(), OP_SELL, pLots, NormalizeDouble(Bid, Digits),
                      sp, NormalizeDouble(StopShort(Ask, sl), Digits),
                      NormalizeDouble(TakeShort(Bid, tp), Digits), pComment,
                      pMagic, pDatetime, pColor);
        if (!CheckError()) break;
      }
  }
  return (ticket);
}

double StopLong(double price, int stop) {
  if (stop == 0)
    return (0);
  else
    return (price - stop * Point);
}

double StopShort(double price, int stop) {
  if (stop == 0)
    return (0);
  else
    return (price + stop * Point);
}

double TakeLong(double price, int stop) {
  if (stop == 0)
    return (0);
  else
    return (price + stop * Point);
}

double TakeShort(double price, int stop) {
  if (stop == 0)
    return (0);
  else
    return (price - stop * Point);
}

double CalculateProfit() {
  double Profit = 0;
  for (count = OrdersTotal() - 1; count >= 0; count--) {
    if (!OrderSelect(count, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      if (OrderType() == OP_BUY || OrderType() == OP_SELL)
        Profit += OrderProfit();
  }
  return (Profit);
}

void TrailingAlls(int pType, int stop, double AvgPrice) {
  if (stop != 0) {
    for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
      if (OrderSelect(trade, SELECT_BY_POS, MODE_TRADES)) {
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
          continue;
        if (OrderSymbol() == Symbol() || OrderMagicNumber() == MagicNumber) {
          if (OrderType() == OP_BUY) {
            double stoptrade = 0;
            double stopcal = 0;
            int profit = 0;
            profit = NormalizeDouble((Bid - AvgPrice) / Point, 0);
            if (profit < pType) continue;
            stoptrade = OrderStopLoss();
            stopcal = Bid - stop * Point;
            if (stoptrade == 0.0 || (stopcal > stoptrade)) {
              if (!OrderModify(OrderTicket(), AvgPrice, stopcal,
                               OrderTakeProfit(), 0, Aqua)) {
                CheckError();
              }
            }
          }
          if (OrderType() == OP_SELL) {
            profit = NormalizeDouble((AvgPrice - Ask) / Point, 0);
            if (profit < pType) continue;
            stoptrade = OrderStopLoss();
            stopcal = Ask + stop * Point;
            if (stoptrade == 0.0 || (stopcal < stoptrade)) {
              if (!OrderModify(OrderTicket(), AvgPrice, stopcal,
                               OrderTakeProfit(), 0, Red)) {
                CheckError();
              }
            }
          }
        }
        Sleep(1000);
      }
    }
  }
}

double AccountEquityHigh() {
  if (CountTrades() == 0) AccntEquityHighAmt = AccountEquity();
  if (AccntEquityHighAmt < PrevEquity)
    AccntEquityHighAmt = PrevEquity;
  else
    AccntEquityHighAmt = AccountEquity();
  PrevEquity = AccountEquity();

  return (AccntEquityHighAmt);
}

double FindLastBuyPrice() {
  double oldorderopenprice;
  int oldticketnumber;
  int ticketnumber = 0;
  for (count = OrdersTotal() - 1; count >= 0; count--) {
    if (!OrderSelect(count, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber &&
        OrderType() == OP_BUY) {
      oldticketnumber = OrderTicket();
      if (oldticketnumber > ticketnumber) {
        oldorderopenprice = OrderOpenPrice();
        ticketnumber = oldticketnumber;
      }
    }
  }
  return (oldorderopenprice);
}

double FindLastSellPrice() {
  double oldorderopenprice;
  int oldticketnumber;
  int ticketnumber = 0;
  for (count = OrdersTotal() - 1; count >= 0; count--) {
    if (!OrderSelect(count, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber &&
        OrderType() == OP_SELL) {
      oldticketnumber = OrderTicket();
      if (oldticketnumber > ticketnumber) {
        oldorderopenprice = OrderOpenPrice();
        ticketnumber = oldticketnumber;
      }
    }
  }
  return (oldorderopenprice);
}

int CheckError() {
  int error = GetLastError();
  Alert("An erroror occured: " + error);

  return (error == 4      /* SERVER_BUSY */
          || error == 137 /* BROKER_BUSY */
          || error == 146 /* TRADE_CONTEXT_BUSY */
          || error == 136 /* OFF_QUOTES */);
}
