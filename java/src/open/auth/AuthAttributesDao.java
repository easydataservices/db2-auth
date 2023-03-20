package com.easydataservices.open.auth;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.sql.Array;
import java.sql.Blob;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Struct;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Logger;
import com.easydataservices.open.auth.StoreAttribute;
import com.easydataservices.open.auth.util.Mask;

/**
 * DAO methods for session attributes.
 *
 * @author jeremy.rickard@easydataservices.com
 */
public class AuthAttributesDao {
  private static final String className = AuthAttributesDao.class.getName();
  private static final Logger logger = Logger.getLogger(className);
  private final short maxSmallint = 32767;
  private Connection connection;
  private String schemaName;
  Array attributeArray;

  /**
   * Constructor.
   * @param connection {@link Connection} to session repository database.
   * @param schemaName Schema name for sessions repository.
   */
  public AuthAttributesDao(Connection connection, String schemaName) {
    logger.finer(() -> String.format("ENTRY %s %s %s", this, connection, schemaName));
    this.connection = connection;
    this.schemaName = schemaName;
    logger.finer(() -> String.format("RETURN %s", this));
  }

  /**
   * Retrieve attributes.
   * @param sessionId Session identifier.
   * @param sinceGenerationId Earliest attribute generation to include in returned attributes.
   * @return List of session attributes.
   */
  public List<StoreAttribute> getAttributes(String sessionId, int sinceGenerationId) throws SQLException {
    final String maskedSessionId = Mask.last(sessionId, 4);
    List<StoreAttribute> sessionAttributes = new ArrayList<StoreAttribute>();

    logger.finer(() -> String.format("ENTRY %s %s", this, maskedSessionId));
    String sql = "CALL " + schemaName + ".attributes.get_attributes(?, ?, ?)";
    try (CallableStatement statement = connection.prepareCall(sql)) {
      logger.fine(() -> String.format("Retrieving current attribute set id... [%s %s]", this, maskedSessionId));
      logger.fine(() -> String.format("Calling stored procedure... [%s %s]", this, maskedSessionId));
      statement.setString(1, sessionId);
      statement.setInt(2, sinceGenerationId);
      statement.registerOutParameter(3, Types.ARRAY);
      statement.execute();

      logger.fine(() -> String.format("Building session attribute list... [%s %s]", this, maskedSessionId));
      Array attributeArray = statement.getArray(3);
      if (attributeArray != null) {
        Struct[] attributeStructs = (Struct[]) attributeArray.getArray();
        for (int i = 0; i < attributeStructs.length; i++) {
          Struct attributeStruct = attributeStructs[i];
          Object[] attributeObject = attributeStruct.getAttributes();
          StoreAttribute attribute = new StoreAttribute((String) attributeObject[0]);
          Blob blob = (Blob) attributeObject[1];
          try (
            InputStream inputStream = blob.getBinaryStream();
            ObjectInputStream objectInputStream = new ObjectInputStream(inputStream);  
          )
          {
            Object object = objectInputStream.readObject();
            attribute.setObject(object);  
            sessionAttributes.add(attribute);  
          }
          catch (ClassNotFoundException exception) {
            logger.severe(() -> String.format("RETURN %s %s %s", this, maskedSessionId, exception.getMessage()));
            throw new SQLException("ClassNotFoundException occurred when converting attribute object!", "72099");
          }
          catch (IOException exception) {
            logger.severe(() -> String.format("RETURN %s %s %s", this, maskedSessionId, exception.getMessage()));
            throw new SQLException("IOException occurred when converting attribute object!", "72099");
          }    
        }  
      }
    }
    catch (SQLException exception) {
      logger.severe(() -> String.format("RETURN %s %s %s", this, maskedSessionId, exception.getMessage()));
      throw exception;
    }  
    logger.finer(() -> String.format("RETURN %s %s", this, maskedSessionId));
    return sessionAttributes;
  }

  /**
   * Save attributes. The list of attributes passed can include both changed and unchanged attributes; however, passing only
   * changes attributes is more efficient. Attributes passed with a {@code null} object are treated as deletions.
   * @param sessionId Session identifier.
   * @param sessionAttributes List of session attributes.
   */
  public void saveAttributes(String sessionId, List<StoreAttribute> sessionAttributes) throws SQLException {
    final String maskedSessionId = Mask.last(sessionId, 4);

    logger.finer(() -> String.format("ENTRY %s %s", this, maskedSessionId));
    String sql = "CALL " + schemaName + ".attributes.save_attributes(?, ?)";
    try (CallableStatement statement = connection.prepareCall(sql)) {
      logger.fine(() -> String.format("Loading session attribute details into SQL array variable... [%s %s]", this, maskedSessionId));
      Struct[] attributeStructs = new Struct[sessionAttributes.size()];
      int i = 0;
      for (StoreAttribute attribute : sessionAttributes) {
        byte[] objectBytes = null;
        Blob blob = null;
        if (attribute.getObject() != null) {
          try (
            ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
            ObjectOutputStream objectOutputStream = new ObjectOutputStream(byteArrayOutputStream);  
          )
          {
            objectOutputStream.writeObject(attribute.getObject());
            objectBytes = byteArrayOutputStream.toByteArray();
            blob = new javax.sql.rowset.serial.SerialBlob(objectBytes);
          }
          catch (IOException exception) {
            logger.severe(() -> String.format("RETURN %s %s %s", this, maskedSessionId, exception.getMessage()));
            throw new SQLException("IOException occurred when converting attribute object!", "72099");
          }      
        }
        Object[] attributeObject = new Object[] {attribute.getAttributeName(), blob};
        Struct attributeStruct = connection.createStruct(schemaName + ".ATTRIBUTES.SESSION_ATTRIBUTE", attributeObject);
        attributeStructs[i] = attributeStruct;
        i = i + 1;
      }
      attributeArray = connection.createArrayOf(schemaName + "ATTRIBUTES.SESSION_ATTRIBUTE", attributeStructs);

      logger.fine(() -> String.format("Calling stored procedure... [%s %s]", this, maskedSessionId));
      statement.setString(1, sessionId);
      statement.setArray(2, attributeArray);
      statement.execute();
    }
    catch (SQLException exception) {
      logger.severe(() -> String.format("RETURN %s %s %s", this, maskedSessionId, exception.getMessage()));
      throw exception;
    }
    logger.finer(() -> String.format("RETURN %s %s", this, maskedSessionId));
  }
}
