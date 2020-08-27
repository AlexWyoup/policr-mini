import React from "react";
import { Helmet } from "react-helmet";

export default ({ children: children }) => {
  return (
    <Helmet>
      <title>{`${children} - ${
        _GLOBAL.botName || _GLOBAL.botFirstName
      }`}</title>
    </Helmet>
  );
};
