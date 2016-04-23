package terrajava.examples.extension;

public class Accumulator {

  static {
    System.loadLibrary("extension");
  }

  private double value;

  public double getValue() {
    return this.value;
  }

  public double sign() {
    return Math.signum(this.value);
  }

  public native void add(int x);
  public native void add(double x);

  public native void sqrt();

  public native boolean isPos();

  public static void main(String[] args) {
     Accumulator acc = new Accumulator();
     acc.add(25);
     acc.sqrt();
     System.out.println(acc.getValue());
     System.out.println(acc.isPos());
  }

}
