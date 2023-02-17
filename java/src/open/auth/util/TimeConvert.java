package com.easydataservices.open.auth.util;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.TimeZone;

/**
 * TimeConvert class. Used for time conversions.
 *
 * @author jeremy.rickard@easydataservices.com
 */
public class TimeConvert {
  final long offsetSeconds = (TimeZone.getDefault().getRawOffset() / 1000);

  /**
   * Convert UTC SQL {@link Timestamp} to UTC {@link Instant}.
   * @param utcTimestamp UTC {@code Timestamp} to convert.
   * @return Converted UTC {@code Instant}.
   */
  public static Instant toUtcInstant(Timestamp utcTimestamp) {
    return utcTimestamp.toLocalDateTime().toInstant(ZoneOffset.UTC);
  }
}