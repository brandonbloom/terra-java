package terrajava;

import java.lang.ClassLoader;
import java.io.*;

/**
 * Supplies static methods needed by the Terra-Java compiler.
 */
public class Lib {

  /**
   * Searches resources and classpath to get the contents of a classfile.
   * @param name the fully qualified name of the class to find.
   * @return the bytes of the classfile found.
   */
  static public byte[] getClassBytes(String name) throws IOException {
    String path = name.replace('.', '/') + ".class";
    InputStream stream = ClassLoader.getSystemResourceAsStream(path);
    if (stream == null) {
      return null;
    }
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
