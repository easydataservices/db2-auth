package com.easydataservices.open.auth;

/**
 * StoreAttribute object, representing a persisted session attribute.
 *
 * @author jeremy.rickard@easydataservices.com
 */
public class StoreAttribute {
  private String attributeName;
  private int generationId;
  private Object object;

  /**
   * Constructor.
   * @param attributeId Attribute identifier. Identifies a session attribute uniquely within the session.
   */
  public StoreAttribute(String attributeName) {
    this.attributeName = attributeName;
  }

  /**
   * Return the attribute name. Identifies a session attribute uniquely within the session.
   * @return Attribute name.
   */
  public String getAttributeName() {
    return attributeName; 
  }

  /**
   * Return the attribute generation. This is used for delta loading.
   * @return Attribute generation identifier.
   */
  public int getGenerationId() {
    return generationId; 
  }

  /**
   * Return the attribute object.
   * @return Object.
   */
  public Object getObject() {
    return object; 
  }

  /**
   * Set the attribute generation. This is used for delta loading.
   * @param generationId Attribute generation identifier.
   */
  public void setGenerationId(int generationId) {
    this.generationId = generationId; 
  }

 /**
   * Set the attribute object.
   * @param object Object.
   */
  public void setObject(Object object) {
    this.object = object; 
  }  
}
