namespace Domain.ValueObjects;

public class Capacity
{
    public double Value { get; }
    public string Unit { get; }

    public Capacity(double value, string unit = "MW")
    {
        Value = value;
        Unit = unit;
    }
}
