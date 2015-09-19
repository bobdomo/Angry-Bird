uchar bit_flags            = 0;
bool flag                  = FALSE; /* bit flag 00000001 */
bool long_trade            = FALSE; /* bit flag 00000010 */
bool new_orders_placed     = FALSE; /* bit flag 00000100 */
bool short_trade           = FALSE; /* bit flag 00001000 */
bool trade_now             = FALSE; /* bit flag 00010000 */
bool use_equity_stop       = FALSE; /* bit flag 00100000 */
bool use_timeout           = FALSE; /* bit flag 01000000 */
bool use_trailing_stop     = FALSE; /* bit flag 10000000 */
double AccntEquityHighAmt  = 0;
double AveragePrice        = 0;
double BuyLimit            = 0;
double BuyTarget           = 0;
double Drop                = 500;
double iLots               = 0;
double LastBuyPrice        = 0;
double LastSellPrice       = 0;
double MaxTradeOpenHours   = 48.0;
double PrevEquity          = 0;
double PriceTarget         = 0;
double RsiMaximum          = 70.0;
double RsiMinimum          = 30.0;
double SellLimit           = 0;
double SellTarget          = 0;
double slip                = 3.0;
double Spread              = 0;
double StartEquity         = 0;
double Stoploss            = 500.0;
double Stopper             = 0.0;
double TotalEquityRisk     = 20.0;
double TrailStart          = 10.0;
extern bool dynamic_pips   = TRUE;
extern double lot_exponent = 2;
extern double lots         = 0.01;
extern double take_profit  = 1500.0;
extern double trail_stop   = 9000;
extern int max_trades      = 5;
extern int min_pip_height  = 1500;
extern int pip_divisor     = 2;
extern int pip_memory      = 120;
int cnt                    = 0;
int expiration             = 0;
int lotdecimal             = 2;
int MagicNumber            = 2222;
int NumOfTrades            = 0;
int PipStep                = 0;
int ticket                 = 0;
int timeprev               = 0;
int total                  = 0;
string EAName              = "Ilan1.6";

/* Init */
int init() {
  Spread = MarketInfo(Symbol(), MODE_SPREAD) * Point;
  return (0);
}

/* Deinit */
int deinit() { return (0); }

/* Debug */
void Debug() {
  Comment("Bit flags: " + bit_flags);
}

/* Start loop */
int start() {
  /* Debug */
  Debug();
  /* Dynamic Pips */
  if (dynamic_pips) {
    /* Calculate highest and lowest price from last bar to X bars ago */
    double hival = High[iHighest(NULL, 0, MODE_HIGH, pip_memory, 1)];
    double loval = Low[iLowest(NULL, 0, MODE_LOW, pip_memory, 1)];
    /* Calculate pips for spread between orders */
    PipStep = NormalizeDouble((hival - loval) / pip_divisor / Point, 0);
    /* If dynamic pips fail, assign pips extreme value */
    if (PipStep < min_pip_height / pip_divisor) {
      PipStep = NormalizeDouble(min_pip_height / pip_divisor, 0);
    }
    if (PipStep > min_pip_height * pip_divisor) {
      PipStep = NormalizeDouble(min_pip_height * pip_divisor, 0);
    }
  } else {
    PipStep = min_pip_height;
  }

  /* Trailing stop */
  if (use_trailing_stop) {
    TrailingAlls(TrailStart, trail_stop, AveragePrice);
  }

  /* Timeout */
  if ((iCCI(NULL, 15, 55, 0, 0) > Drop && short_trade) ||
      (iCCI(NULL, 15, 55, 0, 0) < (-Drop) && long_trade)) {
    CloseThisSymbolAll();
    Print("Closed All due to TimeOut");
  }

  /* ??? */
  if (timeprev == Time[0]) {
    return (0);
  }
  timeprev = Time[0];

  /* Equitiy stop */
  double CurrentPairProfit = CalculateProfit();
  if (use_equity_stop) {
    if (CurrentPairProfit < 0.0 &&
        MathAbs(CurrentPairProfit) >
            TotalEquityRisk / 100.0 * AccountEquityHigh()) {
      CloseThisSymbolAll();
      Print("Closed All due to Stop Out");
      new_orders_placed = FALSE;
    }
  }

  /* Trades */
  total = CountTrades();
  if (total == 0) flag = FALSE;
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    };
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
    LastBuyPrice = FindLastBuyPrice();
    LastSellPrice = FindLastSellPrice();
    if (long_trade && LastBuyPrice - Ask >= PipStep * Point) trade_now = TRUE;
    if (short_trade && Bid - LastSellPrice >= PipStep * Point) trade_now = TRUE;
  }
  if (total < 1) {
    short_trade = FALSE;
    long_trade = FALSE;
    trade_now = TRUE;
    StartEquity = AccountEquity();
  }
  if (trade_now) {
    LastBuyPrice = FindLastBuyPrice();
    LastSellPrice = FindLastSellPrice();
    if (short_trade) {
      NumOfTrades = total;
      iLots = NormalizeDouble(lots * MathPow(lot_exponent, NumOfTrades),
                              lotdecimal);
      RefreshRates();
      ticket = OpenPendingOrder(1, iLots, Bid, slip, Ask, 0, 0,
                                EAName + "-" + NumOfTrades + "-" + PipStep,
                                MagicNumber, 0, HotPink);
      Print(CountTrades());
      LastSellPrice = FindLastSellPrice();
      trade_now = FALSE;
      new_orders_placed = TRUE;
    } else {
      if (long_trade) {
        NumOfTrades = total;
        iLots = NormalizeDouble(lots * MathPow(lot_exponent, NumOfTrades),
                                lotdecimal);
        ticket = OpenPendingOrder(0, iLots, Ask, slip, Bid, 0, 0,
                                  EAName + "-" + NumOfTrades + "-" + PipStep,
                                  MagicNumber, 0, Lime);
        LastBuyPrice = FindLastBuyPrice();
        trade_now = FALSE;
        new_orders_placed = TRUE;
      }
    }
    if (ticket < 0) {
      CheckError();
      return (-1);
    }
  }
  if (trade_now && total < 1) {
    double PrevCl = iClose(Symbol(), 0, 2);
    double CurrCl = iClose(Symbol(), 0, 1);
    SellLimit = Bid;
    BuyLimit = Ask;
    if (!short_trade && !long_trade) {
      NumOfTrades = total;
      iLots = NormalizeDouble(lots * MathPow(lot_exponent, NumOfTrades),
                              lotdecimal);
      if (PrevCl > CurrCl) {
        if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) > RsiMinimum) {
          ticket = OpenPendingOrder(1, iLots, SellLimit, slip, SellLimit, 0, 0,
                                    EAName + "-" + NumOfTrades, MagicNumber, 0,
                                    HotPink);
          LastBuyPrice = FindLastBuyPrice();
          new_orders_placed = TRUE;
        }
      } else {
        if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) < RsiMaximum) {
          ticket = OpenPendingOrder(0, iLots, BuyLimit, slip, BuyLimit, 0, 0,
                                    EAName + "-" + NumOfTrades, MagicNumber, 0,
                                    Lime);
          LastSellPrice = FindLastSellPrice();
          new_orders_placed = TRUE;
        }
      }
      if (ticket < 0) {
        CheckError();
        return (0);
      } else {
        expiration = TimeCurrent() + 60.0 * (60.0 * MaxTradeOpenHours);
      }
      trade_now = FALSE;
    }
  }
  total = CountTrades();
  AveragePrice = 0;
  double Count = 0;
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    }
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
    for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
      if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
        CheckError();
      }
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
        continue;
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
        if (OrderType() == OP_BUY) {
          PriceTarget = AveragePrice + take_profit * Point;
          BuyTarget = PriceTarget;
          Stopper = AveragePrice - Stoploss * Point;
          flag = TRUE;
        }
      }
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
        if (OrderType() == OP_SELL) {
          PriceTarget = AveragePrice - take_profit * Point;
          SellTarget = PriceTarget;
          Stopper = AveragePrice + Stoploss * Point;
          flag = TRUE;
        }
      }
    }
  }
  if (new_orders_placed) {
    if (flag == TRUE) {
      for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
        if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
          CheckError();
        }
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
          continue;
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
          if (!OrderModify(OrderTicket(), NormalizeDouble(AveragePrice, Digits),
                           NormalizeDouble(OrderStopLoss(), Digits),
                           NormalizeDouble(PriceTarget, Digits), 0, Yellow)) {
            CheckError();
          }
        }
        new_orders_placed = FALSE;
      }
    }
  }

  /* End loop */
  return (0);
}

/*Helper functions*/
int CountTrades() {
  int count = 0;
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
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
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
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
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
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
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
bool CheckError() {
  int err = GetLastError();
  if (err) Print("Error: " + err);
  return (err == 4 /* SERVER_BUSY */ || err == 137 /* BROKER_BUSY */
          || err == 146 /* TRADE_CONTEXT_BUSY */ ||
          err == 136 /* OFF_QUOTES */);
}
