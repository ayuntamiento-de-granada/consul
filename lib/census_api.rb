include DocumentParser
class CensusApi

  def call(document_type, document_number, postal_code)
    response = nil
    get_document_number_variants(document_type, document_number).each do |variant|
      response = Response.new(get_response_body(variant, postal_code))
      return response if response.valid?
    end
    response
  end

  class Response
    def initialize(body)
      @body = body
    end

    def valid?
      data[:Consulta_sim][:REGISTRO].present?
    end

    def district_code
      data[:Consulta_sim][:REGISTRO][:RESPUESTA]
    end

    private

      def data
        if Rails.env.development?
          @body[:ejecutar_consulta_response][:return]
        else
          Hash.from_xml(@body[:ejecutar_consulta_response][:return].gsub("\n", ""))
        end
      end
  end

  private

    def get_response_body(document_number, postal_code)
      if end_point_available?
        client.call(:ejecutar_consulta, message: request(document_number, postal_code)).body
      else
        stubbed_response(document_number, postal_code)
      end
    end

    def client
      @client = Savon.client(wsdl: Rails.application.secrets.census_api_end_point)
    end

    def request(document_number, postal_code)
      {
        servicio: "CONSPDR3",
        params: "P1=#{document_number}&P2=#{postal_code}",
        packetsize: 1
      }
    end

    def end_point_available?
      Rails.env.staging? || Rails.env.preproduction? || Rails.env.production?
    end

    def stubbed_response(document_number, postal_code)
      if (document_number == "12345678Z" || document_number == "12345678Y")
        stubbed_valid_response
      else
        stubbed_invalid_response
      end
    end

    def stubbed_valid_response
      {
        ejecutar_consulta_response: {
          return: {
            Consulta_sim: {
              Bookmark: "",
              Recsreaded: "1",
              REGISTRO: {
                RESPUESTA: "BEIRO"
              }
            }
          }
        }
      }
    end

    def stubbed_invalid_response
      {
        ejecutar_consulta_response: {
          return: {
            Consulta_sim: {
              Bookmark: "",
              Recsreaded: "1",
              REGISTRO: nil
            }
          }
        }
      }
    end

    def dni?(document_type)
      document_type.to_s == "1"
    end

end
