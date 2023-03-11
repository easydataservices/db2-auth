package com.easydataservices.open.auth;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Struct;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.logging.Logger;
import com.easydataservices.open.auth.StoreSession;
import com.easydataservices.open.auth.util.Mask;
import com.easydataservices.open.auth.util.TimeConvert;

/**
 * DAO methods for session retrieval by application.
 *
 * @author jeremy.rickard@easydataservices.com
 */
public class AuthSessionDao {
  private static final String className = AuthSessionDao.class.getName();
  private static final Logger logger = Logger.getLogger(className);
  private Connection connection;
  private String schemaName;

  /**
   * Constructor.
   * @param connection {@link Connection} to session repository database.
   * @param schemaName Schema name for session repository.
   */
  public AuthSessionDao(Connection connection, String schemaName) {
    logger.finer(() -> String.format("ENTRY %s %s %s", this, connection, schemaName));
    this.connection = connection;
    this.schemaName = schemaName;
    logger.finer(() -> String.format("RETURN %s", this));
  }

  /**
   * Retrieve the specified session.
   * @param sessionId StoreSession identifier.
   * @return Store session object; {@code null} if no session is retrieved.
   */
  public StoreSession getSession(String sessionId) throws SQLException {
    final String maskedSessionId = Mask.last(sessionId, 4);
    StoreSession session = null;

    logger.finer(() -> String.format("ENTRY %s %s", this, maskedSessionId));
    String sql = "CALL " + schemaName + ".session.get_session(?, ?)";
    try (CallableStatement statement = connection.prepareCall(sql)) {
      logger.fine(() -> String.format("Calling stored procedure... [%s %s]", this, maskedSessionId));
      statement.setString(1, sessionId);
      statement.registerOutParameter(2, Types.STRUCT);
      statement.execute();

      logger.fine(() -> String.format("Getting return values... [%s %s]", this, maskedSessionId));
      Struct sessionInfoStruct = (Struct) statement.getObject(2);
      Object[] sessionInfoObject = sessionInfoStruct.getAttributes();
      if (sessionInfoObject[0] != null) {
        session = new StoreSession(sessionId);
        session.setCreatedTime(TimeConvert.toUtcInstant((Timestamp) sessionInfoObject[0]));
        session.setLastAccessedTime(TimeConvert.toUtcInstant((Timestamp) sessionInfoObject[1]));
        if (sessionInfoObject[2] != null) {
          session.setLastAuthenticatedTime(TimeConvert.toUtcInstant((Timestamp) sessionInfoObject[2]));
        }
        session.setMaxIdleMinutes(((Integer) sessionInfoObject[3]).shortValue());
        session.setMaxAuthenticationMinutes(((Integer) sessionInfoObject[4]).shortValue());
        session.setExpiryTime(TimeConvert.toUtcInstant((Timestamp) sessionInfoObject[5]));
        session.setAuthName(((String) sessionInfoObject[6]));
        session.setPropertiesJson(((String) sessionInfoObject[7]));
        session.setAuthenticated(((boolean) sessionInfoObject[8]));
        session.setExpired(((boolean) sessionInfoObject[9]));
        session.setAttributeGenerationId(((int) sessionInfoObject[10]));      
      }
    }
    catch (Exception exception) {
      logger.severe(() -> String.format("RETURN %s %s %s", this, maskedSessionId, exception.getMessage()));
      throw exception;
    }
    logger.finer(() -> String.format("RETURN %s %s", this, maskedSessionId));
    return session;
  }
}
