module Agents
  class RappelConsoGouvAgent < Agent
    include FormConfigurable

    can_dry_run!
    no_bulk_receive!
    default_schedule '12h'

    description do
      <<-MD
      The huginn catalog agent checks if new campaign is available.

      `debug` is used to verbose mode.

      `number_of_result` is for limiting result output.

      `changes_only` is only used to emit event about a currency's change.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "datasetid": "rappelconso0",
            "recordid": "2eec1943f5368c400d8e7def8264ca40e4c7a3e2",
            "fields": {
              "conditionnements": "barquette 125g x2",
              "motif_du_rappel": "présence de morceaux de plastiques bleus",
              "distributeurs": "Novoviande",
              "temperature_de_conservation": "Produit à conserver au réfrigérateur",
              "zone_geographique_de_vente": "France entière",
              "date_de_fin_de_la_procedure_de_rappel": "mercredi 7 juillet 2021",
              "ndeg_de_version": 1,
              "marque_de_salubrite": "FR 13.097.003 CE",
              "nature_juridique_du_rappel": "Volontaire",
              "identification_des_produits": "21151-4509 Date limite de consommation 08/06/2021",
              "nom_de_la_marque_du_produit": "La belle nature",
              "preconisations_sanitaires": "En raison du risque de blessures / effets indésirables suite à l'ingestion de ce produit, par précaution il est recommandé aux personnes qui détiendraient des produits appartenant au(x) lot(s) décrit(s) ci-dessus de ne pas les consommer.",
              "date_debut_fin_de_commercialisation": "Du 31/05/2021 au 08/06/2021",
              "conduites_a_tenir_par_le_consommateur": "Ne plus consommer",
              "modalites_de_compensation": "Remboursement",
              "noms_des_modeles_ou_references": "Steak haché 5% X2 125G",
              "categorie_de_produit": "Alimentation",
              "sous_categorie_de_produit": "Viandes",
              "reference_fiche": "2021-06-0295",
              "risques_encourus_par_le_consommateur": "Inertes (verre, métal, plastique, papier, textile…)",
              "date_ref": "2021-06",
              "numero_de_contact": "0490478930"
            },
            "record_timestamp": "2021-06-15T01:00:00.756+02:00"
          }
    MD

    def default_options
      {
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
        'number_of_result' => '10',
        'changes_only' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :number_of_result, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :debug, type: :boolean

    def validate_options
      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end

      unless options['number_of_result'].present? && options['number_of_result'].to_i > 0
        errors.add(:base, "Please provide 'number_of_result' to limit the result's number")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      fetch
    end

    private

    def fetch
      uri = URI.parse("https://data.economie.gouv.fr/api/records/1.0/search/?dataset=rappelconso0&q=&rows=#{interpolated['number_of_result']}&sort=date_de_publication")
      request = Net::HTTP::Get.new(uri)
      request["Authority"] = "data.economie.gouv.fr"
      request["Accept"] = "application/json, text/plain, */*"
#      request["X-Csrftoken"] = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Safari/537.36"
      request["Sec-Gpc"] = "1"
      request["Sec-Fetch-Site"] = "same-origin"
      request["Sec-Fetch-Mode"] = "cors"
      request["Sec-Fetch-Dest"] = "empty"
      request["Accept-Language"] = "fr,en-US;q=0.9,en;q=0.8"
#      request["Cookie"] = "csrftoken=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log "request  status : #{response.code}"

      payload = JSON.parse(response.body)

      if interpolated['debug'] == 'true'
        log payload
      end
      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          if "#{memory['last_status']}" == ''
            payload['records'].each do |recordid|
                create_event payload: recordid
            end
          else
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil,", ": null,")
            last_status = JSON.parse(last_status)
            payload['records'].each do |recordid|
              found = false
              if interpolated['debug'] == 'true'
                log "recordid"
                log recordid
              end
              last_status['records'].each do |recordidbis|
                if recordid['recordid'] == recordidbis['recordid']
                  found = true
                end
                if interpolated['debug'] == 'true'
                  log "recordidbis"
                  log recordidbis
                  log "found is #{found}!"
                end
              end
              if found == false
                if interpolated['debug'] == 'true'
                  log "found is #{found}! so event created"
                  log recordid
                end
                create_event payload: recordid
              end
            end
          end
          memory['last_status'] = payload.to_s
        end
      else
        create_event payload: payload
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
        end
      end
    end
  end
end
