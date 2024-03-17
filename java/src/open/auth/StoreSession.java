package com.easydataservices.open.auth;

import java.time.Instant;

/**
 * StoreSession object, representing a persisted session.
 *
 * @author jeremy.rickard@easydataservices.com
 */
public class StoreSession {
  private String sessionId;
  private Instant createdTime;
  private Instant lastAccessedTime;
  private Instant lastAuthenticatedTime;
  private Short maxIdleMinutes;
  private Short maxAuthenticationMinutes;
  private Instant expiryTime;
  private String authName;
  private String propertiesJson;
  private boolean isAuthenticated;
  private boolean isExpired;
  private int attributeGenerationId;

  /**
   * Constructor.
   * @param sessionId Identifier of session to create.
   */
  public StoreSession(String sessionId) {
    this.sessionId = sessionId;
  }

  /**
   * Return the session identifier.
   * @return Session identifier.
   */
  public String getSessionId() {
    return sessionId; 
  }

  /**
   * Return the time that the session was created.
   * @return Created time.
   */
  public Instant getCreatedTime() {
    return createdTime;
  }

  /**
   * Return the time that the session was last accessed by a user request.
   * @return Last accessed time.
   */
  public Instant getLastAccessedTime() {
    return lastAccessedTime;
  }

  /**
   * Return the time that the session was last authenticated.
   * @return Last authenticated time.
   */
  public Instant getLastAuthenticatedTime() {
    return lastAuthenticatedTime;
  }

  /**
   * Return the maximum inactive interval between requests before the session will be invalidated.
   * @return Maximum inactive interval in minutes.
   */
  public Short getMaxIdleMinutes() {
    return maxIdleMinutes;
  }

  /**
   * Return the maximum interval since authentication after which the session will be invalidated.
   * @return Maximum interval since authenticatio in minutes.
   */
  public Short getMaxAuthenticationMinutes() {
    return maxAuthenticationMinutes;
  }

  /**
   * Return the time that the session expired, or will expiry without intervention.
   * @return Expiry time.
   */
  public Instant getExpiryTime() {
    return expiryTime;
  }

  /**
   * Return the authorisation name
   * @return Authorisation name (e.g. user login).
   */
  public String getAuthName() {
    return authName; 
  }

  /**
   * Return additional properties in JSON format.
   * @return JSON properties.
   */
  public String getPropertiesJson() {
    return propertiesJson; 
  }

  /**
   * Return flag indicating whether or not a session user is authenticated.
   * @return {@code true} if the session user is authenticated; otherwise {@code false}.
   */
  public boolean isAuthenticated() {
    return isAuthenticated; 
  }

  /**
   * Return flag indicating whether or not a session is expired.
   * @return {@code true} if the session is expired; otherwise {@code false}.
   */
  public boolean isExpired() {
    return isExpired; 
  }

  /**
   * Return latest (highest) attribute generation associated with the session. The initial value is 0.
   * @return Latest attribute generation id.
   */
  public int getAttributeGenerationId() {
    return attributeGenerationId; 
  }

  /**
   * Set the time that the session was created.
   * @param createdTime Created time.
   */
  protected void setCreatedTime(Instant createdTime) {
    this.createdTime = createdTime;
  }

  /**
   * Set the time that the session was last accessed by a user request.
   * @param lastAccessedTime Last accessed time.
   */
  protected void setLastAccessedTime(Instant lastAccessedTime) {
    this.lastAccessedTime = lastAccessedTime;
  }

  /**
   * Set the time that the session was last authenticated.
   * @param lastAuthenticatedTime Last authenticated time.
   */
  protected void setLastAuthenticatedTime(Instant lastAuthenticatedTime) {
    this.lastAuthenticatedTime = lastAuthenticatedTime;
  }

  /**
   * Set the maximum inactive interval between requests before the session will be invalidated.
   * @param maxIdleMinutes Maximum inactive interval in minutes.
   */
  protected void setMaxIdleMinutes(Short maxIdleMinutes) {
    this.maxIdleMinutes = maxIdleMinutes;
  }

  /**
   * Set the maximum interval since authentication after which the session will be invalidated.
   * @param maxAuthenticationMinutes Maximum interval since authentication in minutes.
   */
  protected void setMaxAuthenticationMinutes(Short maxAuthenticationMinutes) {
    this.maxAuthenticationMinutes = maxAuthenticationMinutes;
  }

  /**
   * Set the time that the session expired, or will expiry without intervention.
   * @param expiryTime Expiry time.
   */
  protected void setExpiryTime(Instant expiryTime) {
    this.expiryTime = expiryTime;
  }

  /**
   * Set the authorisation name
   * @param authName Authorisation name (e.g. user login).
   */
  protected void setAuthName(String authName) {
    this.authName = authName;
  }

  /**
   * Set additional properties in JSON format.
   * @param JSON properties.
   */
  protected void setPropertiesJson(String propertiesJson) {
    this.propertiesJson = propertiesJson; 
  }

  /**
   * Set flag indicating whether or not a session user is authenticated.
   * @param isAuthenticated {@code true} if the session user is authenticated; otherwise {@code false}.
   */
  protected void setAuthenticated(boolean isAuthenticated) {
    this.isAuthenticated = isAuthenticated;
  }

  /**
   * Set flag indicating whether or not a session is expired.
   * @param isExpired {@code true} if the session is expired; otherwise {@code false}.
   */
  protected void setExpired(boolean isExpired) {
    this.isExpired = isExpired;
  }

  /**
   * Set latest (highest) attribute generation associated with the session.
   * @param attributeGenerationId Latest attribute generation id.
   */
  public void setAttributeGenerationId(int attributeGenerationId) {
    this.attributeGenerationId = attributeGenerationId; 
  }  
}
