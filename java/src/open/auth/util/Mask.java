package com.easydataservices.open.auth.util;

import java.util.Arrays;

/**
 * Mask class. Used to mask sensitive data.
 *
 * @author jeremy.rickard@easydataservices.com
 */
public class Mask {
  final static char maskChar = '*';

  /**
   * Mask all characters except exempt portion at end.
   * @param text Unmasked input text.
   * @param exempt Number of end characters exempted from mask.
   * @return Masked text.
   */
  public static String last(String text, int exempt) {
    if (text == null) {
      return null;
    }
    if (text.length() <= exempt || exempt < 0) {
      return text;
    }
    int masked = text.length() - exempt;
    char[] charArray = new char[masked];
    Arrays.fill(charArray, maskChar);
    return new String(charArray) + text.substring(masked);
  }
}