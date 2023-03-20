package com.easydataservices.open.auth;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Struct;
import java.util.logging.Logger;
import com.easydataservices.open.auth.util.Mask;

/**
 * DAO methods for session control.
 *
 * @author jeremy.rickard@easydataservices.com
 */
public class AuthControlDao {
  private static final String className = AuthControlDao.class.getName();
  private static final Logger logger = Logger.getLogger(className);
  private Connection connection;
  private String schemaName;

  /**
   * Constructor.
   * @param connection {@link Connection} to session repository database.
   * @param schemaName Schema name for session repository.
   */
  public AuthControlDao(Connection connection, String schemaName) {
    logger.finer(() -> String.format("ENTRY %s %s %s", this, connection, schemaName));
    this.connection = connection;
    this.schemaName = schemaName;
    logger.finer(() -> String.format("RETURN %s", this));
  }

  /**
   * Add a new session to the database.
   * @param sessionId Session identifier of new session.
   * @param sessionConfig Object array of configuration properties (for row type CONTROL.SESSION_CONFIG).
   */
  public void addSession(String sessionId, Object[] sessionConfig) throws SQLException {
    final String maskedSessionId = Mask.last(sessionId, 4);

    logger.finer(() -> String.format("ENTRY %s %s", this, maskedSessionId));
    Struct sessionConfigStruct = connection.createStruct(schemaName + ".CONTROL.SESSION_CONFIG", sessionConfig);
    String sql = "CALL " + schemaName + ".control.add_session(?, ?)";
    try (CallableStatement statement = connection.prepareCall(sql)) {
      logger.fine(() -> String.format("Calling stored procedure... [%s %s]", this, maskedSessionId));
      statement.setString(1, sessionId);
      statement.setObject(2, sessionConfigStruct);
      statement.execute();
    }
    catch (Exception exception) {
      logger.severe(() -> String.format("RETURN %s %s %s", this, maskedSessionId, exception.getMessage()));
      throw exception;
    }
    logger.finer(() -> String.format("RETURN %s %s", this, maskedSessionId));
  }

  /**
   * Update session configuration. This is normally used to mark a session authenticated (or reauthenticated), after
   * {@link StoreSession#setAuthName setAuthName} has been used to set the authorisation name.
   * @param sessionId Session identifier of authenticated session.
   * @param sessionConfig Object array of configuration properties (for row type CONTROL.SESSION_CONFIG).
   */
  public void changeSessionConfig(String sessionId, Object[] sessionConfig) throws SQLException {
    final String maskedSessionId = Mask.last(sessionId, 4);

    logger.finer(() -> String.format("ENTRY %s %s", this, maskedSessionId));
    Struct sessionConfigStruct = connection.createStruct(schemaName + ".CONTROL.SESSION_CONFIG", sessionConfig);
    String sql = "CALL " + schemaName + ".control.change_session_config(?, ?)";
    try (CallableStatement statement = connection.prepareCall(sql)) {
      logger.fine(() -> String.format("Calling stored procedure... [%s %s]", this, maskedSessionId));
      statement.setString(1, sessionId);
      statement.setObject(2, sessionConfigStruct);
      statement.execute();
    }
    catch (Exception exception) {
      logger.severe(() -> String.format("RETURN %s %s %s", this, maskedSessionId, exception.getMessage()));
      throw exception;
    }
    logger.finer(() -> String.format("RETURN %s %s", this, maskedSessionId));
  }

  /**
   * Remove session from database.
   * @param sessionId Session identifier of session to remove.
   */
  public void removeSession(String sessionId) throws SQLException {
    final String maskedSessionId = Mask.last(sessionId, 4);

    logger.finer(() -> String.format("ENTRY %s %s", this, maskedSessionId));
    String sql = "CALL " + schemaName + ".control.remove_session(?)";
    try (CallableStatement statement = connection.prepareCall(sql)) {
      logger.fine(() -> String.format("Calling stored procedure... [%s %s]", this, maskedSessionId));
      statement.setString(1, sessionId);
      statement.execute();
    }
    catch (Exception exception) {
      logger.severe(() -> String.format("RETURN %s %s %s", this, maskedSessionId, exception.getMessage()));
      throw exception;
    }  
    logger.finer(() -> String.format("RETURN %s %s", this, maskedSessionId));
  }

  /**
   * Change session identfier.
   * @param sessionId Current session identifier.
   * @param newSessionId New session identifier.
   */
  public void changeSessionId(String sessionId, String newSessionId) throws SQLException {
    final String maskedSessionId = Mask.last(sessionId, 4);
    final String maskedNewSessionId = Mask.last(newSessionId, 4);

    logger.finer(() -> String.format("ENTRY %s %s %s", this, maskedSessionId, maskedNewSessionId));
    String sql = "CALL " + schemaName + ".control.change_session_id(?, ?)";
    try (CallableStatement statement = connection.prepareCall(sql)) {
      logger.fine(() -> String.format("Calling stored procedure... [%s %s]", this, maskedSessionId));
      statement.setString(1, sessionId);
      statement.setString(2, newSessionId);
      statement.execute();
    }
    catch (Exception exception) {
      logger.severe(() -> String.format("RETURN %s %s %s", this, maskedSessionId, exception.getMessage()));
      throw exception;
    }  
    logger.finer(() -> String.format("RETURN %s %s", this, maskedSessionId));
  }
}
