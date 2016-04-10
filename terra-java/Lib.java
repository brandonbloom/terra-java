package terrajava;

import java.lang.ClassLoader;
import java.io.*;

public class Lib {

  static public byte[] getClassBytes(String name) throws IOException {
    String path = name.replace('.', '/') + ".class";
    InputStream stream = ClassLoader.getSystemResourceAsStream(path);
    return toByteArray(stream);
  }

  private static byte[] toByteArray(InputStream in) throws IOException {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    byte[] buf = new byte[1024];
    while (true) {
      int r = in.read(buf);
      if (r == -1) {
        break;
      }
      out.write(buf, 0, r);
    }
    return out.toByteArray();
  }

}
