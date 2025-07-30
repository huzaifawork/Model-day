class Job {
  final String? id;
  final DateTime? createdDate;
  final DateTime? updatedDate;
  final String? createdBy;
  final bool isSample;
  final String clientName;
  final String type;
  final String location;
  final String? bookingAgent;
  final String date;
  final String? time;
  final String? endTime;
  final double rate;
  final String? currency;
  final String? files;
  final Map<String, dynamic>? fileData;
  final String? notes;
  final String? status;
  final String? paymentStatus;
  final String? requirements;
  final List<String>? images;
  final double? extraHours;
  final double? agencyFeePercentage;
  final double? taxPercentage;
  final double? additionalFees;

  Job({
    this.id,
    this.createdDate,
    this.updatedDate,
    this.createdBy,
    this.isSample = false,
    required this.clientName,
    required this.type,
    required this.location,
    this.bookingAgent,
    required this.date,
    this.time,
    this.endTime,
    this.rate = 0,
    this.currency,
    this.files,
    this.fileData,
    this.notes,
    this.status = 'pending',
    this.paymentStatus = 'unpaid',
    this.requirements,
    this.images,
    this.extraHours,
    this.agencyFeePercentage,
    this.taxPercentage,
    this.additionalFees,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      createdDate: json['created_date'] != null
          ? DateTime.parse(json['created_date'])
          : null,
      updatedDate: json['updated_date'] != null
          ? DateTime.parse(json['updated_date'])
          : null,
      createdBy: json['created_by'],
      isSample: json['is_sample'] ?? false,
      clientName: json['client_name'] ?? '',
      type: json['type'] ?? '',
      location: json['location'] ?? '',
      bookingAgent: json['booking_agent'],
      date: json['date'] ?? '',
      time: json['time'],
      endTime: json['end_time'],
      rate: (json['rate'] ?? 0).toDouble(),
      currency: json['currency'],
      files: json['files'],
      fileData: json['file_data'] as Map<String, dynamic>?,
      notes: json['notes'],
      status: json['status'] ?? 'pending',
      paymentStatus: json['payment_status'] ?? 'unpaid',
      requirements: json['requirements'],
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      extraHours: json['extra_hours']?.toDouble(),
      agencyFeePercentage: json['agency_fee_percentage']?.toDouble(),
      taxPercentage: json['tax_percentage']?.toDouble(),
      additionalFees: json['additional_fees']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_date': createdDate?.toIso8601String(),
      'updated_date': updatedDate?.toIso8601String(),
      'created_by': createdBy,
      'is_sample': isSample,
      'client_name': clientName,
      'type': type,
      'location': location,
      'booking_agent': bookingAgent,
      'date': date,
      'time': time,
      'end_time': endTime,
      'rate': rate,
      'currency': currency,
      'files': files,
      'file_data': fileData,
      'notes': notes,
      'status': status,
      'payment_status': paymentStatus,
      'requirements': requirements,
      'images': images,
      'extra_hours': extraHours,
      'agency_fee_percentage': agencyFeePercentage,
      'tax_percentage': taxPercentage,
      'additional_fees': additionalFees,
    };
  }

  String? formatTime() {
    if (time == null) return null;
    return time;
  }

  double calculateTotal() {
    // Start with base rate
    double subtotal = rate;

    // Add extra hours (calculated at 10% of rate per hour)
    if (extraHours != null) {
      subtotal += extraHours! * (rate * 0.1);
    }

    // Add additional fees
    if (additionalFees != null) {
      subtotal += additionalFees!;
    }

    // Calculate agency fee (percentage of subtotal)
    double afterAgencyFee = subtotal;
    if (agencyFeePercentage != null) {
      final agencyFee = subtotal * (agencyFeePercentage! / 100);
      afterAgencyFee = subtotal - agencyFee; // Agency fee is deducted
    }

    // Calculate tax (percentage of amount after agency fee)
    double finalTotal = afterAgencyFee;
    if (taxPercentage != null) {
      final tax = afterAgencyFee * (taxPercentage! / 100);
      finalTotal = afterAgencyFee - tax; // Tax is deducted
    }

    return finalTotal;
  }

  // Helper method to calculate extra hours amount
  double calculateExtraHoursAmount() {
    if (extraHours == null) return 0.0;
    return extraHours! * (rate * 0.1);
  }

  // Helper method to calculate agency fee amount
  double calculateAgencyFeeAmount() {
    if (agencyFeePercentage == null) return 0.0;
    final subtotal =
        rate + calculateExtraHoursAmount() + (additionalFees ?? 0.0);
    return subtotal * (agencyFeePercentage! / 100);
  }

  // Helper method to calculate tax amount
  double calculateTaxAmount() {
    if (taxPercentage == null) return 0.0;
    final subtotal =
        rate + calculateExtraHoursAmount() + (additionalFees ?? 0.0);
    final afterAgencyFee = subtotal - calculateAgencyFeeAmount();
    return afterAgencyFee * (taxPercentage! / 100);
  }

  Job copyWith({
    String? id,
    DateTime? createdDate,
    DateTime? updatedDate,
    String? createdBy,
    bool? isSample,
    String? clientName,
    String? type,
    String? location,
    String? bookingAgent,
    String? date,
    String? time,
    String? endTime,
    double? rate,
    String? currency,
    String? files,
    Map<String, dynamic>? fileData,
    String? notes,
    String? status,
    String? paymentStatus,
    String? requirements,
    List<String>? images,
    double? extraHours,
    double? agencyFeePercentage,
    double? taxPercentage,
    double? additionalFees,
  }) {
    return Job(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      createdBy: createdBy ?? this.createdBy,
      isSample: isSample ?? this.isSample,
      clientName: clientName ?? this.clientName,
      type: type ?? this.type,
      location: location ?? this.location,
      bookingAgent: bookingAgent ?? this.bookingAgent,
      date: date ?? this.date,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      rate: rate ?? this.rate,
      currency: currency ?? this.currency,
      files: files ?? this.files,
      fileData: fileData ?? this.fileData,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      requirements: requirements ?? this.requirements,
      images: images ?? this.images,
      extraHours: extraHours ?? this.extraHours,
      agencyFeePercentage: agencyFeePercentage ?? this.agencyFeePercentage,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      additionalFees: additionalFees ?? this.additionalFees,
    );
  }
}
