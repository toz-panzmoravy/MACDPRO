//+------------------------------------------------------------------+
//|                                                    MACD Pro.mq5  |
//|                        Funkční MACD indikátor pro MQL5          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.01"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   3

//--- MACD plot
#property indicator_label1  "MACD"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Signal plot
#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Histogram plot
#property indicator_label3  "Histogram"
#property indicator_type3   DRAW_COLOR_HISTOGRAM
#property indicator_color3  clrLime, clrLightGreen, clrLightPink, clrRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//--- Input parameters
input int    FastLength = 12;        // Fast Length
input int    SlowLength = 26;        // Slow Length
input int    SignalLength = 9;       // Signal Smoothing
input ENUM_MA_METHOD OscillatorMAType = MODE_EMA;  // Oscillator MA Type
input ENUM_MA_METHOD SignalMAType = MODE_EMA;      // Signal Line MA Type
input ENUM_APPLIED_PRICE Source = PRICE_CLOSE;     // Source

//--- Indicator buffers
double MACDBuffer[];
double SignalBuffer[];
double HistBuffer[];
double HistColorBuffer[];

//--- Handles
int fastMAHandle = INVALID_HANDLE;
int slowMAHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, MACDBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, HistBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, HistColorBuffer, INDICATOR_COLOR_INDEX);

   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(2, PLOT_COLOR_INDEXES, 4);

   IndicatorSetString(INDICATOR_SHORTNAME, "MACD Pro");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   //--- Create MA handles
   fastMAHandle = iMA(_Symbol, _Period, FastLength, 0, OscillatorMAType, Source);
   slowMAHandle = iMA(_Symbol, _Period, SlowLength, 0, OscillatorMAType, Source);
   if(fastMAHandle == INVALID_HANDLE || slowMAHandle == INVALID_HANDLE)
   {
      Print("Failed to create MA handles");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(fastMAHandle != INVALID_HANDLE) IndicatorRelease(fastMAHandle);
   if(slowMAHandle != INVALID_HANDLE) IndicatorRelease(slowMAHandle);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < SlowLength + SignalLength)
      return(0);

   //--- Prepare temp buffers
   static double fastMABuffer[];
   static double slowMABuffer[];
   ArrayResize(fastMABuffer, rates_total);
   ArrayResize(slowMABuffer, rates_total);

   //--- Copy MA values
   if(CopyBuffer(fastMAHandle, 0, 0, rates_total, fastMABuffer) <= 0) return(0);
   if(CopyBuffer(slowMAHandle, 0, 0, rates_total, slowMABuffer) <= 0) return(0);

   //--- Calculate MACD line
   for(int i = 0; i < rates_total; i++)
      MACDBuffer[i] = fastMABuffer[i] - slowMABuffer[i];

   //--- Calculate Signal line (EMA on MACDBuffer)
   SimpleMAOnArray(MACDBuffer, SignalBuffer, rates_total, SignalLength, SignalMAType);

   //--- Calculate Histogram and set color
   for(int i = 0; i < rates_total; i++)
   {
      HistBuffer[i] = MACDBuffer[i] - SignalBuffer[i];
      //--- Color logic
      if(HistBuffer[i] >= 0)
      {
         if(i > 0 && HistBuffer[i] > HistBuffer[i-1])
            HistColorBuffer[i] = 0; // clrLime
         else
            HistColorBuffer[i] = 1; // clrLightGreen
      }
      else
      {
         if(i > 0 && HistBuffer[i] > HistBuffer[i-1])
            HistColorBuffer[i] = 2; // clrLightPink
         else
            HistColorBuffer[i] = 3; // clrRed
      }
   }
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Simple MA/EMA on array (for Signal line)                         |
//+------------------------------------------------------------------+
void SimpleMAOnArray(const double &src[], double &dst[], int size, int period, ENUM_MA_METHOD method)
{
   if(method == MODE_SMA)
   {
      for(int i = 0; i < size; i++)
      {
         double sum = 0;
         int count = 0;
         for(int j = i; j > i - period && j >= 0; j--)
         {
            sum += src[j];
            count++;
         }
         dst[i] = (count > 0) ? sum / count : 0.0;
      }
   }
   else if(method == MODE_EMA)
   {
      double k = 2.0 / (period + 1);
      dst[0] = src[0];
      for(int i = 1; i < size; i++)
         dst[i] = k * src[i] + (1 - k) * dst[i-1];
   }
   else
   {
      // Pro jiné typy MA lze doplnit další logiku
      for(int i = 0; i < size; i++)
         dst[i] = src[i];
   }
}
//+------------------------------------------------------------------+ 