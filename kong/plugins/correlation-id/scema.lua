return {
    name = "correlation-id",
    fields = {
      { config = {
          type = "record",
          fields = {
            { header_name = { type = "string", default = "X-Correlation-ID" } },
          },
      }, },
    },
  }
  