credential = function(
  xs_a,
  r_12t13_a,
  an_a, 
  
  xs_b, 
  r_12t13_b,
  an_b, 
  
  isotope_rt_delta_s = 5,
  ppm_for_isotopes = 4,
  
  mixed_ratio_factor = 4,
  mixed_ratio_ratio_factor = 1.8,
  xs_a_file=NULL, 
  xs_b_file=NULL,
  mpc_f= 1,
  write_files = T
  ) {
  
  csum=c()
  
  if (!is.null(xs_a_file)) {xs_a@filepaths = xs_a_file  }
  if (!is.null(xs_b_file)) {xs_b@filepaths = xs_b_file  }
  
  data(mpc)
  #mpc = read.csv(header=T, file="dependencies/mm_mpc.csv")
  mpc = mpc[1:150,,drop=F]
  
  peaks_a = prep_peaktable(xs_a@peaks)
  peaks_b = prep_peaktable(xs_b@peaks)
  
  #Generate pairwise matches of isotopic mass within each sample
  pwms_a = pwms(peaks_a, 
                isotope_rt_delta_s = isotope_rt_delta_s, 
                ppm_for_isotopes = ppm_for_isotopes,
                mpc = mpc,
                mpc_f = mpc_f,
                mixed_ratio_12t13 = r_12t13_a,
                mixed_ratio_factor = mixed_ratio_factor)
  has_match_a = sapply(pwms_a, nrow) > 0
  csum = c(csum, paste(sep=" ","A - peaks:",nrow(peaks_a), "Pairwise matches: ",sum(sapply(pwms_a, function(x) { nrow(x) }), na.rm=T), "Has a match: ", sum(has_match_a)))
  
  
  pwms_b = pwms(peaks_b, 
                isotope_rt_delta_s =isotope_rt_delta_s, 
                ppm_for_isotopes =ppm_for_isotopes,
                mpc = mpc,
                mpc_f = mpc_f,
                mixed_ratio_12t13 = r_12t13_b,
                mixed_ratio_factor = mixed_ratio_factor)
  has_match_b = sapply(pwms_b, nrow) > 0
  csum = c(csum, paste(sep=" ","B - peaks:",nrow(peaks_b), "Pairwise matches: ",sum(sapply(pwms_b, function(x) { nrow(x) }), na.rm=T), "Has a match: ", sum(has_match_b)))
                    
  if(length(pwms_a) < 1 || length(pwms_b) < 1) {stop("No pairwise matches found.  Labeled samples? Proper ratio?")}
  
  cat("\nAligning Samples.\n")
  aligns = xsAlignCred(peaks_a[has_match_a,,drop=F], peaks_b[has_match_b,,drop=F], xs_a, xs_b)
  csum = c(csum, paste(sep=" ","Unique peaknum_a aligns: ", length(unique(aligns[,"peaknum_a"])), ". Total aligns: ", nrow(aligns)))

  # Possible alternative, manually group and match.  Probably a good idea.
  #aligns = align(
  #  peaks_a[has_match_a,,drop=F], 
  #  peaks_b[has_match_b,,drop=F],
  #  ppm=30, 
  #  drt=30
  #  )

  
  #Look for patterns of credentialed natural isotopes
  pwms_af = buildChargeSupport(pwms_a)
  pwms_bf = buildChargeSupport(pwms_b)
  
  #Find all putative matches which were replicated aross samples.
  matches = matchAlignsCarbonCharge(aligns, pwms_af, pwms_bf)
  csum = c(csum,  paste(sep=" ","After combination and carbon/charge filtering between samples. Unique peaknum_a aligns: ", length(unique(matches[,"master_peaknum_a"])), ". Total possibilities: ", nrow(matches)))
   

  # Adds from xsAnnotate: ciso_a, ciso_b, ccharge_a, ccharge_b, cacharge_a, cacharge_b, crule_a, crule_b
  m_i = addIsoAdd(matches, an_a, an_b) 
  
  m_ic = filterChargeSupport(m_i)
  csum = c(csum,  paste(sep=" ","After filtering based on charge support. Unique peaknum_a aligns: ", length(unique(m_ic[,"master_peaknum_a"])), ". Total possibilities: ", nrow(m_ic)))
           
  m_icm = filterMaxo(
    m_ic, 
    peaks_a,
    peaks_b,
    maxo_r_a = r_12t13_a,
    maxo_r_b = r_12t13_b,
    maxo_r_fs = mixed_ratio_factor,
    maxo_r_fc = mixed_ratio_ratio_factor
  )
 csum = c(csum,  paste(sep=" ","After filtering based on maxo ratios. Unique peaknum_a aligns: ", length(unique(m_icm[,"master_peaknum_a"])), ". Total possibilities: ", nrow(m_icm)))
           
  #Remove camera isotopes
  m_icmi = filterIsos(m_icm)
  csum = c(csum,  paste(sep=" ","After filtering based on CAMERA isotopes. Unique peaknum_a aligns: ", length(unique(m_icmi[,"master_peaknum_a"])), ". Total possibilities: ", nrow(m_icmi)))
           
  #Remove duplicated matches to partially labeled U13C peaks
  #m_cmip = filterPartialLabeling(m_cm)
  
  # Remove very similar peaks found by the peakfinding (errors?)
  m_icmid = removeDuplicatePeakPicks(m_icmi)
  csum = c(csum,  paste(sep=" ","After filtering peakpicking duplicates. Unique peaknum_a aligns: ", length(unique(m_icmid[,"master_peaknum_a"])), ". Total possibilities: ", nrow(m_icmid)))
           
  #Filters based on isotope support
  m_icmidp = filterPeakSupport(m_icmid)
  csum = c(csum,  paste(sep=" ","After filtering based on isotope support. Unique peaknum_a aligns: ", length(unique(m_icmidp[,"master_peaknum_a"])), ". Total possibilities: ", nrow(m_icmidp)))
           
  # Last resort, picks the lowest charge
  m_icmidpc = pickLowestCharge(m_icmidp)
  csum = c(csum,  paste(sep=" ","After filtering for lowest charge state. Unique peaknum_a aligns: ", length(unique(m_icmidpc[,"master_peaknum_a"])), ". Total possibilities: ", nrow(m_icmidpc)))
           
  #Last last resort. Don't care as long as C# is correct
  m_icmidpcn = cNumMatters(m_icmidpc)
  csum = c(csum,  paste(sep=" ","After filtering by assuming the common carbon number is correct (bad filter). Unique peaknum_a aligns: ", length(unique(m_icmidpcn[,"master_peaknum_a"])), ". Total possibilities: ", nrow(m_icmidpcn)))
           
  #Last last last resort. Pick heaviest
  m_icmidpcnh = heaviestMatters(m_icmidpcn)
  csum = c(csum,  paste(sep=" ","After filtering by picking the heaviest match (bad filter). Unique peaknum_a aligns: ", length(unique(m_icmidpcnh[,"master_peaknum_a"])), ". Total possibilities: ", nrow(m_icmidpcnh)))
           
  #########################################
  #Any filtering before this step is good - Just discard inderminant peaks
  mf_lst = selectBest(m_icmidpcnh)
  mf = mf_lst$good_peaks
  
  cfs = formatPeaks(mf, peaks_a)
  csum = c(csum,  paste(sep=" ","Good credentialed features (credentialed_features.csv): ", nrow(cfs)))
           
  
  bcfs = formatPeaks(mf_lst$bad_peaks, peaks_a)
  csum = c(csum,  paste(sep=" ","Bad credentialed features (credentialed_features_bad.csv): ", nrow(bcfs)))
  
  if (write_files) {
    write.csv(cfs, "credentialed_features.csv")
    writeLines(csum, "credential_summary.txt")
    write.csv(bcfs, "credentialed_features_bad.csv")
  }
  
  return(cfs)
}