package com.easydataservices.open.auth;

import java.time.Instant;

/**
 * SessionConfig object, for passing attributes for the {@code CONTROL.SESSION_CONFIG} row type.
 *
 * @author jeremy.rickard@easydataservices.com
 */
public class SessionConfig {
  private Instant changeTime;
  private String authName;
  private Short maxIdleMinutes;
  private String propertiesJson;

  /**
   * Set the time that the configuration was changed. If not set (or set outside valid range) then the current time
   * will be used,
   * @param changeTime Change time.
   */
  public void setChangeTime(Instant changeTime) {
    this.changeTime = changeTime;
  }

  /**
   * Set the authorisation name
   * @param authName Authorisation name (e.g. user login).
   */
  public void setAuthName(String authName) {
    this.authName = authName;
  }

  /**
   * Set the maximum inactive interval between requests before the session will be invalidated.
   * @param maxIdleMinutes Maximum inactive interval in minutes.
   */
  public void setMaxIdleMinutes(Short maxIdleMinutes) {
    this.maxIdleMinutes = maxIdleMinutes;
  }

  /**
   * Set additional properties in JSON format.
   * @param JSON properties.
   */
  public void setPropertiesJson(String propertiesJson) {
    this.propertiesJson = propertiesJson; 
  }

  /**
   * Return object array for JDBC row type.
   * @return Object array,
   */
  protected Object[] getRowObject() {
    return new Object[] {changeTime, authName, maxIdleMinutes, propertiesJson};
  }
}
